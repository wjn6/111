#!/usr/bin/env node
/**
 * 初始化脚本 - 创建配置文件和第一个管理员用户
 */
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// 生成随机 API Key
function generateApiKey() {
  const randomBytes = crypto.randomBytes(36);
  const key = randomBytes.toString('base64')
    .replace(/[+/=]/g, '')
    .substring(0, 48);
  return `sk-admin-${key}`;
}

// 主函数
async function main() {
  console.log('🚀 Antigravity API 初始化脚本\n');

  // 1. 创建 data 目录
  const dataDir = path.join(__dirname, 'data');
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
    console.log('✅ 已创建 data 目录');
  }

  // 2. 检查配置文件
  const configPath = path.join(__dirname, 'config.json');
  const configExamplePath = path.join(__dirname, 'config.json.example');

  if (!fs.existsSync(configPath)) {
    if (fs.existsSync(configExamplePath)) {
      // 复制示例配置
      let config = JSON.parse(fs.readFileSync(configExamplePath, 'utf8'));
      
      // 生成新的 admin API Key
      const adminApiKey = generateApiKey();
      config.security.adminApiKey = adminApiKey;
      
      // 写入配置
      fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
      
      console.log('✅ 已创建 config.json');
      console.log(`\n📝 管理员 API Key: ${adminApiKey}`);
      console.log('   请妥善保管此密钥！\n');
    } else {
      console.log('❌ 未找到 config.json.example 文件');
      process.exit(1);
    }
  } else {
    console.log('ℹ️  config.json 已存在，跳过创建');
  }

  console.log('\n🎉 初始化完成！\n');
  console.log('下一步操作：');
  console.log('  1. 本地运行: npm install && npm start');
  console.log('  2. Docker 部署: docker-compose up -d --build');
  console.log('\n服务启动后访问: http://localhost:8045');
}

main().catch(console.error);
