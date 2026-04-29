-- 删除付费相关表（如果存在）
DROP TABLE IF EXISTS payment_orders;
DROP TABLE IF EXISTS token_tiers;

-- 删除用户表的付费字段（如果存在）
ALTER TABLE users DROP COLUMN IF EXISTS token_balance;
ALTER TABLE users DROP COLUMN IF EXISTS token_tier;

-- 添加 API 配置字段
ALTER TABLE users ADD COLUMN IF NOT EXISTS use_shared_config BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS shared_config_type VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_llm_base_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_llm_api_key TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_vision_base_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_vision_api_key TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verified_at TIMESTAMP;
