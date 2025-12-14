-- SQLite Schema for Antigravity API Proxy
-- 转换自 PostgreSQL 版本

-- 启用外键支持
PRAGMA foreign_keys = ON;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    api_key TEXT NOT NULL UNIQUE,
    name TEXT,
    prefer_shared INTEGER DEFAULT 0 NOT NULL CHECK (prefer_shared IN (0, 1)),
    status INTEGER DEFAULT 1 NOT NULL CHECK (status IN (0, 1)),
    created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- 账号表
CREATE TABLE IF NOT EXISTS accounts (
    cookie_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    is_shared INTEGER DEFAULT 0 NOT NULL CHECK (is_shared IN (0, 1)),
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    expires_at INTEGER,
    status INTEGER DEFAULT 1 NOT NULL CHECK (status IN (0, 1)),
    created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    need_refresh INTEGER DEFAULT 0 NOT NULL CHECK (need_refresh IN (0, 1)),
    name TEXT,
    email TEXT UNIQUE,
    project_id_0 TEXT DEFAULT '',
    is_restricted INTEGER DEFAULT 0 NOT NULL CHECK (is_restricted IN (0, 1)),
    paid_tier INTEGER DEFAULT 0 CHECK (paid_tier IN (0, 1)),
    ineligible INTEGER DEFAULT 0 NOT NULL CHECK (ineligible IN (0, 1)),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- 模型配额表
CREATE TABLE IF NOT EXISTS model_quotas (
    quota_id TEXT PRIMARY KEY,
    cookie_id TEXT NOT NULL,
    model_name TEXT NOT NULL,
    reset_time TEXT,
    quota REAL DEFAULT 1.0 NOT NULL,
    status INTEGER DEFAULT 1 NOT NULL CHECK (status IN (0, 1)),
    last_fetched_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (cookie_id, model_name),
    FOREIGN KEY (cookie_id) REFERENCES accounts(cookie_id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- 配额消耗记录表
CREATE TABLE IF NOT EXISTS quota_consumption_log (
    log_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    cookie_id TEXT NOT NULL,
    model_name TEXT NOT NULL,
    quota_before REAL NOT NULL,
    quota_after REAL NOT NULL,
    quota_consumed REAL NOT NULL,
    is_shared INTEGER DEFAULT 1 NOT NULL CHECK (is_shared IN (0, 1)),
    consumed_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (cookie_id) REFERENCES accounts(cookie_id) ON DELETE CASCADE
);

-- 用户共享配额池表
CREATE TABLE IF NOT EXISTS user_shared_quota_pool (
    pool_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    model_name TEXT NOT NULL,
    quota REAL DEFAULT 0.0 NOT NULL,
    max_quota REAL DEFAULT 0.0 NOT NULL,
    last_recovered_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    last_updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE (user_id, model_name),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- Kiro账号表
CREATE TABLE IF NOT EXISTS kiro_accounts (
    account_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    account_name TEXT,
    auth_method TEXT NOT NULL CHECK (auth_method IN ('Social', 'IdC', '')),
    refresh_token TEXT NOT NULL,
    access_token TEXT,
    expires_at INTEGER,
    client_id TEXT,
    client_secret TEXT,
    profile_arn TEXT,
    machineid TEXT NOT NULL,
    is_shared INTEGER DEFAULT 0 NOT NULL CHECK (is_shared IN (0, 1)),
    email TEXT,
    userid TEXT NOT NULL,
    subscription TEXT NOT NULL,
    current_usage REAL NOT NULL,
    reset_date TEXT NOT NULL,
    free_trial_status INTEGER DEFAULT 0 NOT NULL CHECK (free_trial_status IN (0, 1)),
    free_trial_usage REAL,
    free_trial_expiry TEXT,
    free_trial_limit REAL NOT NULL DEFAULT 0,
    usage_limit REAL NOT NULL,
    status INTEGER DEFAULT 1 NOT NULL CHECK (status IN (0, 1)),
    created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    need_refresh INTEGER DEFAULT 0 NOT NULL CHECK (need_refresh IN (0, 1)),
    bonus_usage REAL DEFAULT 0,
    bonus_limit REAL DEFAULT 0,
    bonus_available REAL DEFAULT 0,
    bonus_details TEXT DEFAULT '[]',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Kiro消费日志表
CREATE TABLE IF NOT EXISTS kiro_consumption_log (
    log_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    model_id TEXT NOT NULL,
    credit_used REAL NOT NULL,
    is_shared INTEGER DEFAULT 0 NOT NULL CHECK (is_shared IN (0, 1)),
    consumed_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES kiro_accounts(account_id) ON DELETE CASCADE
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_users_api_key ON users(api_key);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_is_shared ON accounts(is_shared);
CREATE INDEX IF NOT EXISTS idx_accounts_status ON accounts(status);
CREATE INDEX IF NOT EXISTS idx_accounts_need_refresh ON accounts(need_refresh);
CREATE INDEX IF NOT EXISTS idx_accounts_paid_tier ON accounts(paid_tier);
CREATE INDEX IF NOT EXISTS idx_accounts_ineligible ON accounts(ineligible);

CREATE INDEX IF NOT EXISTS idx_model_quotas_cookie_id ON model_quotas(cookie_id);
CREATE INDEX IF NOT EXISTS idx_model_quotas_model_name ON model_quotas(model_name);
CREATE INDEX IF NOT EXISTS idx_model_quotas_status ON model_quotas(status);
CREATE INDEX IF NOT EXISTS idx_model_quotas_reset_time ON model_quotas(reset_time);

CREATE INDEX IF NOT EXISTS idx_quota_consumption_user_id ON quota_consumption_log(user_id);
CREATE INDEX IF NOT EXISTS idx_quota_consumption_cookie_id ON quota_consumption_log(cookie_id);
CREATE INDEX IF NOT EXISTS idx_quota_consumption_model_name ON quota_consumption_log(model_name);
CREATE INDEX IF NOT EXISTS idx_quota_consumption_is_shared ON quota_consumption_log(is_shared);
CREATE INDEX IF NOT EXISTS idx_quota_consumption_consumed_at ON quota_consumption_log(consumed_at);

CREATE INDEX IF NOT EXISTS idx_user_shared_quota_pool_user_id ON user_shared_quota_pool(user_id);
CREATE INDEX IF NOT EXISTS idx_user_shared_quota_pool_model_name ON user_shared_quota_pool(model_name);

CREATE INDEX IF NOT EXISTS idx_kiro_accounts_user_id ON kiro_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_userid ON kiro_accounts(userid);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_email ON kiro_accounts(email);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_is_shared ON kiro_accounts(is_shared);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_status ON kiro_accounts(status);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_need_refresh ON kiro_accounts(need_refresh);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_auth_method ON kiro_accounts(auth_method);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_subscription ON kiro_accounts(subscription);
CREATE INDEX IF NOT EXISTS idx_kiro_accounts_bonus_available ON kiro_accounts(bonus_available);

CREATE INDEX IF NOT EXISTS idx_kiro_consumption_user_id ON kiro_consumption_log(user_id);
CREATE INDEX IF NOT EXISTS idx_kiro_consumption_account_id ON kiro_consumption_log(account_id);
CREATE INDEX IF NOT EXISTS idx_kiro_consumption_model_id ON kiro_consumption_log(model_id);
CREATE INDEX IF NOT EXISTS idx_kiro_consumption_is_shared ON kiro_consumption_log(is_shared);
CREATE INDEX IF NOT EXISTS idx_kiro_consumption_consumed_at ON kiro_consumption_log(consumed_at);

-- 共享池配额视图
CREATE VIEW IF NOT EXISTS shared_pool_quotas_view AS
SELECT
    mq.model_name,
    SUM(mq.quota) AS total_quota,
    MIN(mq.reset_time) AS earliest_reset_time,
    COUNT(DISTINCT mq.cookie_id) AS available_cookies,
    CASE WHEN SUM(mq.quota) > 0 THEN 1 ELSE 0 END AS status,
    MAX(mq.last_fetched_at) AS last_fetched_at
FROM model_quotas mq
JOIN accounts a ON mq.cookie_id = a.cookie_id
WHERE a.is_shared = 1 AND a.status = 1 AND mq.status = 1
GROUP BY mq.model_name;

-- 触发器：更新 users 表的 updated_at
CREATE TRIGGER IF NOT EXISTS update_users_updated_at
AFTER UPDATE ON users
BEGIN
    UPDATE users SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE user_id = NEW.user_id;
END;

-- 触发器：更新 accounts 表的 updated_at
CREATE TRIGGER IF NOT EXISTS update_accounts_updated_at
AFTER UPDATE ON accounts
BEGIN
    UPDATE accounts SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE cookie_id = NEW.cookie_id;
END;

-- 触发器：更新 kiro_accounts 表的 updated_at
CREATE TRIGGER IF NOT EXISTS update_kiro_accounts_updated_at
AFTER UPDATE ON kiro_accounts
BEGIN
    UPDATE kiro_accounts SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE account_id = NEW.account_id;
END;
