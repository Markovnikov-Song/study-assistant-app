-- Token计费系统迁移
-- 功能：Token使用统计、用户配额管理、限流

-- ============================================
-- 1. Token使用日志表
-- ============================================
CREATE TABLE IF NOT EXISTS token_usage_log (
    id BIGSERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id INT REFERENCES conversation_sessions(id) ON DELETE SET NULL,
    
    -- Token统计
    model_name VARCHAR(100) NOT NULL,
    input_tokens INT NOT NULL DEFAULT 0,
    output_tokens INT NOT NULL DEFAULT 0,
    total_tokens INT GENERATED ALWAYS AS (input_tokens + output_tokens) STORED,
    
    -- 费用
    api_cost DECIMAL(10,6) NOT NULL DEFAULT 0,
    cost_currency VARCHAR(3) DEFAULT 'CNY',
    
    -- 元数据
    endpoint VARCHAR(50) NOT NULL,  -- chat/stream/embedding/vision/mindmap/lecture/exam
    request_id VARCHAR(64),         -- 请求追踪ID
    ip_address VARCHAR(45),          -- 客户端IP
    user_agent TEXT,
    
    -- 时间戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_token_usage_user_id ON token_usage_log(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage_log(created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_user_created ON token_usage_log(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_token_usage_session ON token_usage_log(session_id);

COMMENT ON TABLE token_usage_log IS 'Token使用日志，记录每次LLM调用的token消耗和费用';
COMMENT ON COLUMN token_usage_log.total_tokens IS 'input_tokens + output_tokens，计算得出';
COMMENT ON COLUMN token_usage_log.api_cost IS '本次请求的API费用（人民币）';


-- ============================================
-- 2. 用户Token配额表
-- ============================================
CREATE TABLE IF NOT EXISTS user_token_quota (
    id BIGSERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 档位配置
    tier VARCHAR(20) NOT NULL DEFAULT 'free',  -- free/mini/standard/plus/enterprise
    tier_expires_at TIMESTAMP WITH TIME ZONE,   -- 档位过期时间
    
    -- 配额限制
    quota_daily INT NOT NULL DEFAULT 50000,      -- 每日Token配额（基础免费额度）
    quota_monthly INT NOT NULL DEFAULT 0,         -- 每月额外Token配额
    
    -- 实际使用量（每日/每月重置）
    used_today INT NOT NULL DEFAULT 0,
    used_this_month INT NOT NULL DEFAULT 0,
    last_reset_date DATE DEFAULT CURRENT_DATE,    -- 上次重置日期
    
    -- 额外包（一次性购买的Token包）
    bonus_tokens INT NOT NULL DEFAULT 0,         -- 额外赠送Token
    bonus_used INT NOT NULL DEFAULT 0,           -- 已使用的赠送Token
    
    -- 超额计费启用
    payg_enabled BOOLEAN NOT NULL DEFAULT TRUE,  -- 是否启用超额按量付费
    
    -- 限流配置
    rate_limit_per_min INT NOT NULL DEFAULT 10,  -- 每分钟请求数限制
    rate_limit_per_hour INT NOT NULL DEFAULT 100, -- 每小时请求数限制
    
    -- 状态
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    block_reason TEXT,
    block_expires_at TIMESTAMP WITH TIME ZONE,
    
    -- 累计统计（不重置）
    total_tokens_all_time BIGINT NOT NULL DEFAULT 0,  -- 历史总消耗
    total_cost_all_time DECIMAL(12,4) NOT NULL DEFAULT 0, -- 历史总费用
    
    -- 时间戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_user_quota_user_id ON user_token_quota(user_id);
CREATE INDEX IF NOT EXISTS idx_user_quota_tier ON user_token_quota(tier);
CREATE INDEX IF NOT EXISTS idx_user_quota_blocked ON user_token_quota(is_blocked) WHERE is_blocked != 0;

COMMENT ON TABLE user_token_quota IS '用户Token配额管理表，记录档位、配额、使用量';
COMMENT ON COLUMN user_token_quota.quota_daily IS '每日基础免费Token配额（不包含额外包）';
COMMENT ON COLUMN user_token_quota.bonus_tokens IS '额外购买的Token包，不计入每日/月限制';


-- ============================================
-- 3. 档位定义表（可选，便于动态管理）
-- ============================================
CREATE TABLE IF NOT EXISTS tier_definitions (
    id BIGSERIAL PRIMARY KEY,
    tier VARCHAR(20) UNIQUE NOT NULL,
    display_name VARCHAR(50) NOT NULL,
    description TEXT,
    
    -- 价格
    price_monthly DECIMAL(10,2) NOT NULL DEFAULT 0,
    price_yearly DECIMAL(10,2),
    
    -- 配额
    daily_quota INT NOT NULL,
    monthly_quota INT NOT NULL DEFAULT 0,
    rate_limit_per_min INT NOT NULL,
    rate_limit_per_hour INT NOT NULL,
    
    -- 功能
    payg_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- 排序
    sort_order INT NOT NULL DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 插入默认档位
INSERT INTO tier_definitions (tier, display_name, description, price_monthly, daily_quota, monthly_quota, rate_limit_per_min, rate_limit_per_hour, payg_enabled, is_active, sort_order)
VALUES 
    ('free', '免费版', '基础功能，每日50K Token', 0, 50000, 0, 10, 100, 1, 1, 1),
    ('mini', '轻量版', '适合轻度学习者', 9.9, 100000, 1000000, 30, 300, 1, 1, 2),
    ('standard', '标准版', '适合日常学习', 29, 300000, 5000000, 60, 600, 1, 1, 3),
    ('plus', '增强版', '适合重度学习/备考', 59, 800000, 15000000, 120, 1200, 1, 1, 4),
    ('enterprise', '企业版', '支持团队/API', 199, 2000000, 50000000, 300, 3000, 0, 1, 5)
ON CONFLICT (tier) DO NOTHING;


-- ============================================
-- 4. 订阅记录表
-- ============================================
CREATE TABLE IF NOT EXISTS user_subscriptions (
    id BIGSERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    tier VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',  -- active/paused/cancelled/expired
    
    -- 订阅周期
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    
    -- 支付信息
    payment_method VARCHAR(20),  -- wechat/alipay/card
    payment_id VARCHAR(100),     -- 第三方支付单号
    amount DECIMAL(10,2) NOT NULL,
    
    -- 自动续费
    auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires ON user_subscriptions(expires_at);

COMMENT ON TABLE user_subscriptions IS '用户订阅记录';


-- ============================================
-- 5. 超额账单表
-- ============================================
CREATE TABLE IF NOT EXISTS token_bills (
    id BIGSERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 账单周期
    bill_period VARCHAR(7) NOT NULL,  -- YYYY-MM 格式
    
    -- 统计数据
    total_tokens INT NOT NULL DEFAULT 0,
    quota_tokens INT NOT NULL DEFAULT 0,  -- 配额内Token
    overage_tokens INT NOT NULL DEFAULT 0, -- 超额Token
    overage_rate DECIMAL(10,6) NOT NULL,   -- 超额单价（元/Token）
    
    -- 费用
    quota_cost DECIMAL(10,4) NOT NULL DEFAULT 0,  -- 配额内费用（通常为0）
    overage_cost DECIMAL(10,4) NOT NULL DEFAULT 0, -- 超额费用
    total_cost DECIMAL(10,4) NOT NULL DEFAULT 0,
    
    -- 状态
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending/paid/overdue
    paid_at TIMESTAMP WITH TIME ZONE,
    
    -- 支付信息
    payment_method VARCHAR(20),
    payment_id VARCHAR(100),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_token_bills_user_period ON token_bills(user_id, bill_period);
CREATE INDEX IF NOT EXISTS idx_token_bills_status ON token_bills(status);

COMMENT ON TABLE token_bills IS '用户超额Token月度账单';


-- ============================================
-- 6. 每日使用快照（便于统计，防止数据膨胀）
-- ============================================
CREATE TABLE IF NOT EXISTS token_daily_snapshot (
    id BIGSERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    
    -- 当日统计
    total_tokens INT NOT NULL DEFAULT 0,
    total_requests INT NOT NULL DEFAULT 0,
    total_cost DECIMAL(10,6) NOT NULL DEFAULT 0,
    
    -- 按端点分类
    chat_tokens INT NOT NULL DEFAULT 0,
    stream_tokens INT NOT NULL DEFAULT 0,
    mindmap_tokens INT NOT NULL DEFAULT 0,
    lecture_tokens INT NOT NULL DEFAULT 0,
    exam_tokens INT NOT NULL DEFAULT 0,
    vision_tokens INT NOT NULL DEFAULT 0,
    embedding_tokens INT NOT NULL DEFAULT 0,
    other_tokens INT NOT NULL DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_token_snapshot_user_date ON token_daily_snapshot(user_id, snapshot_date);

COMMENT ON TABLE token_daily_snapshot IS 'Token使用每日快照，用于统计报表';


-- ============================================
-- 7. 触发器：自动更新配额使用量
-- ============================================
CREATE OR REPLACE FUNCTION update_quota_usage()
RETURNS TRIGGER AS $$
DECLARE
    v_quota RECORD;
    v_today DATE := CURRENT_DATE;
    v_month_start DATE := DATE_TRUNC('month', CURRENT_DATE);
BEGIN
    -- 获取用户配额
    SELECT * INTO v_quota FROM user_token_quota WHERE user_id = NEW.user_id;
    
    IF v_quota IS NULL THEN
        -- 自动创建免费档配额
        INSERT INTO user_token_quota (user_id, tier, quota_daily, used_today, used_this_month, last_reset_date)
        VALUES (NEW.user_id, 'free', 50000, 0, 0, v_today)
        ON CONFLICT (user_id) DO NOTHING;
        
        SELECT * INTO v_quota FROM user_token_quota WHERE user_id = NEW.user_id;
    END IF;
    
    -- 检查是否需要重置每日/每月计数
    IF v_quota.last_reset_date < v_today THEN
        -- 新的一天，重置每日计数
        UPDATE user_token_quota 
        SET used_today = 0, 
            last_reset_date = v_today,
            updated_at = NOW()
        WHERE user_id = NEW.user_id;
        
        -- 检查是否新月份
        IF EXTRACT(MONTH FROM v_quota.last_reset_date) != EXTRACT(MONTH FROM v_today)
           OR EXTRACT(YEAR FROM v_quota.last_reset_date) != EXTRACT(YEAR FROM v_today) THEN
            -- 新月份，重置每月计数
            UPDATE user_token_quota 
            SET used_this_month = 0,
                updated_at = NOW()
            WHERE user_id = NEW.user_id;
        END IF;
    END IF;
    
    -- 更新配额使用量
    UPDATE user_token_quota 
    SET 
        used_today = used_today + NEW.total_tokens,
        used_this_month = used_this_month + NEW.total_tokens,
        total_tokens_all_time = total_tokens_all_time + NEW.total_tokens,
        total_cost_all_time = total_cost_all_time + NEW.api_cost,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_quota_on_usage ON token_usage_log;
CREATE TRIGGER trigger_update_quota_on_usage
    AFTER INSERT ON token_usage_log
    FOR EACH ROW
    EXECUTE FUNCTION update_quota_usage();


-- ============================================
-- 8. 视图：用户Token使用概览
-- ============================================
CREATE OR REPLACE VIEW v_user_token_overview AS
SELECT 
    u.id AS user_id,
    u.username,
    q.tier,
    q.quota_daily,
    q.quota_monthly,
    q.used_today,
    q.used_this_month,
    q.bonus_tokens,
    q.bonus_used,
    q.total_tokens_all_time,
    q.total_cost_all_time,
    q.is_blocked,
    q.rate_limit_per_min,
    q.rate_limit_per_hour,
    
    -- 计算剩余
    GREATEST(0, q.quota_daily - q.used_today) AS remaining_today,
    GREATEST(0, q.quota_monthly - q.used_this_month) AS remaining_monthly,
    (q.bonus_tokens - q.bonus_used) AS remaining_bonus,
    
    -- 计算使用率
    CASE WHEN q.quota_daily > 0 
         THEN ROUND((q.used_today::NUMERIC / q.quota_daily) * 100, 1)
         ELSE 100 
    END AS daily_usage_percent,
    
    CASE WHEN q.quota_monthly > 0 
         THEN ROUND((q.used_this_month::NUMERIC / q.quota_monthly) * 100, 1)
         ELSE 0 
    END AS monthly_usage_percent,
    
    -- 档位信息
    t.display_name AS tier_display_name,
    t.price_monthly AS tier_price
FROM users u
LEFT JOIN user_token_quota q ON u.id = q.user_id
LEFT JOIN tier_definitions t ON q.tier = t.tier;

COMMENT ON VIEW v_user_token_overview IS '用户Token使用概览视图';
