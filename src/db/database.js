import Database from 'better-sqlite3';
import { randomUUID } from 'crypto';
import fs from 'fs';
import path from 'path';
import logger from '../utils/logger.js';

class SQLiteDatabase {
  constructor() {
    this.db = null;
  }

  /**
   * 生成UUID
   * @returns {string} UUID字符串
   */
  generateUUID() {
    return randomUUID();
  }

  /**
   * 初始化数据库连接
   * @param {Object} config - 数据库配置
   * @param {string} config.filename - 数据库文件路径
   */
  initialize(config) {
    if (this.db) {
      logger.warn('数据库连接已存在，将关闭旧连接');
      this.db.close();
    }

    // 支持 config 为 undefined 或空对象的情况
    const dbPath = (config && config.filename) ? config.filename : './data/antigravity.db';
    
    // 确保数据目录存在
    const dbDir = path.dirname(dbPath);
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }

    this.db = new Database(dbPath);
    
    // 启用外键支持
    this.db.pragma('foreign_keys = ON');
    // 设置WAL模式提升性能
    this.db.pragma('journal_mode = WAL');
    
    // 初始化表结构
    this.initSchema();

    logger.info(`SQLite数据库已初始化: ${dbPath}`);
  }

  /**
   * 初始化数据库表结构
   */
  initSchema() {
    const schemaPath = path.join(process.cwd(), 'schema.sql');
    if (fs.existsSync(schemaPath)) {
      const schema = fs.readFileSync(schemaPath, 'utf8');
      this.db.exec(schema);
      logger.info('数据库表结构已初始化');
    } else {
      logger.warn('未找到 schema.sql 文件，跳过表结构初始化');
    }
  }

  /**
   * 将PostgreSQL风格的参数占位符转换为SQLite风格
   * PostgreSQL: $1, $2, $3 -> SQLite: ?, ?, ?
   * @param {string} sql - SQL语句
   * @returns {string} 转换后的SQL语句
   */
  convertPlaceholders(sql) {
    return sql.replace(/\$\d+/g, '?');
  }

  /**
   * 移除PostgreSQL特有的类型转换语法
   * @param {string} sql - SQL语句
   * @returns {string} 转换后的SQL语句
   */
  removePgCasts(sql) {
    // 移除 ::uuid, ::numeric, ::TEXT 等类型转换
    return sql.replace(/::\w+/g, '');
  }

  /**
   * 转换SQL语句（PostgreSQL -> SQLite）
   * @param {string} sql - SQL语句
   * @returns {string} 转换后的SQL语句
   */
  convertSQL(sql) {
    let converted = sql;
    
    // 转换参数占位符
    converted = this.convertPlaceholders(converted);
    
    // 移除类型转换
    converted = this.removePgCasts(converted);
    
    // 转换 CURRENT_TIMESTAMP
    converted = converted.replace(/CURRENT_TIMESTAMP/g, "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')");
    
    // 转换 COALESCE 中的 TRUE/FALSE
    converted = converted.replace(/\bTRUE\b/gi, '1');
    converted = converted.replace(/\bFALSE\b/gi, '0');
    
    // 转换 NULLS FIRST/LAST（SQLite不支持，需要用CASE模拟，但这里简化处理直接移除）
    converted = converted.replace(/\s+NULLS\s+(FIRST|LAST)/gi, '');
    
    return converted;
  }

  /**
   * 执行SQL查询（兼容PostgreSQL的query接口）
   * @param {string} text - SQL查询语句
   * @param {Array} params - 查询参数
   * @returns {Object} 查询结果 { rows: [], rowCount: number }
   */
  query(text, params = []) {
    if (!this.db) {
      throw new Error('数据库未初始化，请先调用 initialize() 方法');
    }

    try {
      const sql = this.convertSQL(text);
      const trimmedSQL = sql.trim().toUpperCase();
      
      // 判断是SELECT还是其他操作
      if (trimmedSQL.startsWith('SELECT')) {
        const stmt = this.db.prepare(sql);
        const rows = stmt.all(...params);
        return { rows, rowCount: rows.length };
      } else if (trimmedSQL.includes('RETURNING')) {
        // 处理带RETURNING的INSERT/UPDATE/DELETE
        // SQLite不原生支持RETURNING，需要模拟
        const returningMatch = sql.match(/RETURNING\s+(.+?)$/i);
        const baseSql = sql.replace(/\s+RETURNING\s+.+$/i, '');
        
        const stmt = this.db.prepare(baseSql);
        const info = stmt.run(...params);
        
        // 尝试获取返回的行
        let rows = [];
        if (info.changes > 0) {
          // 根据SQL类型确定如何获取返回行
          if (trimmedSQL.startsWith('INSERT')) {
            // 获取最后插入的行
            const tableName = this.extractTableName(baseSql, 'INSERT');
            const pkColumn = this.getPrimaryKeyColumn(tableName);
            if (pkColumn && info.lastInsertRowid) {
              const selectStmt = this.db.prepare(`SELECT * FROM ${tableName} WHERE rowid = ?`);
              rows = [selectStmt.get(info.lastInsertRowid)].filter(Boolean);
            }
          } else if (trimmedSQL.startsWith('UPDATE')) {
            // UPDATE时无法直接获取更新的行，需要在调用方单独查询
            // 这里返回空，让调用方处理
          } else if (trimmedSQL.startsWith('DELETE')) {
            // DELETE后行已删除，无法返回
          }
        }
        
        return { rows, rowCount: info.changes };
      } else {
        // INSERT/UPDATE/DELETE 不带 RETURNING
        const stmt = this.db.prepare(sql);
        const info = stmt.run(...params);
        return { rows: [], rowCount: info.changes };
      }
    } catch (error) {
      logger.error('SQL执行失败:', text, error.message);
      throw error;
    }
  }

  /**
   * 执行INSERT并返回插入的行
   * @param {string} tableName - 表名
   * @param {Object} data - 要插入的数据
   * @param {string} idColumn - ID列名（默认自动检测）
   * @returns {Object} 插入的行
   */
  insert(tableName, data, idColumn = null) {
    const columns = Object.keys(data);
    const values = Object.values(data);
    const placeholders = columns.map(() => '?').join(', ');
    
    const sql = `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES (${placeholders})`;
    const stmt = this.db.prepare(sql);
    const info = stmt.run(...values);
    
    // 获取插入的行
    const selectStmt = this.db.prepare(`SELECT * FROM ${tableName} WHERE rowid = ?`);
    return selectStmt.get(info.lastInsertRowid);
  }

  /**
   * 执行UPDATE并返回更新的行
   * @param {string} tableName - 表名
   * @param {Object} data - 要更新的数据
   * @param {Object} where - WHERE条件
   * @returns {Object} 更新后的行
   */
  update(tableName, data, where) {
    const setClauses = Object.keys(data).map(k => `${k} = ?`).join(', ');
    const whereClauses = Object.keys(where).map(k => `${k} = ?`).join(' AND ');
    
    const sql = `UPDATE ${tableName} SET ${setClauses} WHERE ${whereClauses}`;
    const params = [...Object.values(data), ...Object.values(where)];
    
    const stmt = this.db.prepare(sql);
    stmt.run(...params);
    
    // 获取更新后的行
    const selectSql = `SELECT * FROM ${tableName} WHERE ${whereClauses}`;
    const selectStmt = this.db.prepare(selectSql);
    return selectStmt.get(...Object.values(where));
  }

  /**
   * 从SQL中提取表名
   * @param {string} sql - SQL语句
   * @param {string} type - SQL类型 (INSERT/UPDATE/DELETE)
   * @returns {string|null} 表名
   */
  extractTableName(sql, type) {
    let match;
    if (type === 'INSERT') {
      match = sql.match(/INSERT\s+INTO\s+(\w+)/i);
    } else if (type === 'UPDATE') {
      match = sql.match(/UPDATE\s+(\w+)/i);
    } else if (type === 'DELETE') {
      match = sql.match(/DELETE\s+FROM\s+(\w+)/i);
    }
    return match ? match[1] : null;
  }

  /**
   * 获取表的主键列名
   * @param {string} tableName - 表名
   * @returns {string|null} 主键列名
   */
  getPrimaryKeyColumn(tableName) {
    const pkMap = {
      'users': 'user_id',
      'accounts': 'cookie_id',
      'model_quotas': 'quota_id',
      'quota_consumption_log': 'log_id',
      'user_shared_quota_pool': 'pool_id',
      'kiro_accounts': 'account_id',
      'kiro_consumption_log': 'log_id'
    };
    return pkMap[tableName] || null;
  }

  /**
   * 获取数据库实例（用于事务等高级操作）
   * @returns {Database} better-sqlite3实例
   */
  getDb() {
    if (!this.db) {
      throw new Error('数据库未初始化，请先调用 initialize() 方法');
    }
    return this.db;
  }

  /**
   * 开始事务
   * @param {Function} fn - 事务函数
   * @returns {any} 事务函数的返回值
   */
  transaction(fn) {
    return this.db.transaction(fn)();
  }

  /**
   * 关闭数据库连接
   */
  async close() {
    if (this.db) {
      this.db.close();
      this.db = null;
      logger.info('SQLite数据库连接已关闭');
    }
  }

  /**
   * 检查数据库连接
   */
  async ping() {
    try {
      this.db.prepare('SELECT 1').get();
      return true;
    } catch (error) {
      logger.error('数据库连接检查失败:', error.message);
      return false;
    }
  }
}

// 导出单例
const database = new SQLiteDatabase();
export default database;
