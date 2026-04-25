-- ============================================================================
-- 迁移 012: 支付系统
-- ============================================================================
-- 表: payment_orders (支付订单)
-- ============================================================================

-- 支付订单表
CREATE TABLE IF NOT EXISTS payment_orders (
    id              SERIAL PRIMARY KEY,
    order_no        VARCHAR(64) UNIQUE NOT NULL,  -- 订单号 (平台生成)
    external_no     VARCHAR(128),                  -- 外部支付单号 (支付宝/微信等)
    
    -- 用户信息
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- 商品信息
    product_type    VARCHAR(32) NOT NULL,  -- subscription(订阅) / bonus(充值)
    product_id      VARCHAR(32),           -- tier名称 或 bonus包ID
    
    -- 金额信息 (单位: 分, 0表示免费/测试)
    amount          INTEGER NOT NULL DEFAULT 0,  -- 支付金额(分)
    currency        VARCHAR(8) DEFAULT 'CNY',
    actual_amount   INTEGER NOT NULL DEFAULT 0,  -- 实付金额(分)
    
    -- 支付渠道
    payment_channel VARCHAR(32) NOT NULL,  -- alipay / wechat / free(免费)
    
    -- 状态: pending/paid/cancelled/refunded/expired
    status          VARCHAR(32) NOT NULL DEFAULT 'pending',
    
    -- 订阅相关
    subscription_months INTEGER DEFAULT 1,  -- 订阅月数
    
    -- 回调信息
    callback_time   TIMESTAMP,
    callback_raw    TEXT,
    
    -- 过期时间 (15分钟)
    expire_at       TIMESTAMP NOT NULL DEFAULT (NOW() + INTERVAL '15 minutes'),
    
    -- 备注
    remark          TEXT,
    
    -- 时间戳
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- 索引
    CONSTRAINT uk_order_no UNIQUE (order_no)
);

-- 订单号索引
CREATE INDEX IF NOT EXISTS idx_payment_orders_order_no ON payment_orders(order_no);

-- 用户订单索引
CREATE INDEX IF NOT EXISTS idx_payment_orders_user_id ON payment_orders(user_id);

-- 状态索引
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON payment_orders(status);

-- 外部单号索引
CREATE INDEX IF NOT EXISTS idx_payment_orders_external ON payment_orders(external_no);

-- 创建时间索引 (用于查询最近订单)
CREATE INDEX IF NOT EXISTS idx_payment_orders_created ON payment_orders(created_at DESC);

-- 过期时间索引 (用于定时清理过期订单)
CREATE INDEX IF NOT EXISTS idx_payment_orders_expire ON payment_orders(expire_at) WHERE status = 'pending';

-- 更新updated_at的触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 绑定触发器
DROP TRIGGER IF EXISTS update_payment_orders_updated_at ON payment_orders;
CREATE TRIGGER update_payment_orders_updated_at
    BEFORE UPDATE ON payment_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 迁移完成
-- ============================================================================
