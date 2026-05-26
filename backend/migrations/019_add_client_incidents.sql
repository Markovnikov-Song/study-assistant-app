-- 客户端问题反馈收件箱
CREATE TABLE IF NOT EXISTS client_incidents (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(64) NOT NULL DEFAULT '',
    route VARCHAR(512) NOT NULL DEFAULT '',
    description TEXT,
    contact VARCHAR(256),
    app_version VARCHAR(32) NOT NULL DEFAULT '',
    device_info JSONB NOT NULL DEFAULT '{}',
    client_logs JSONB NOT NULL DEFAULT '[]',
    has_screenshot BOOLEAN NOT NULL DEFAULT FALSE,
    storage_dir VARCHAR(512) NOT NULL DEFAULT '',
    status VARCHAR(16) NOT NULL DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_client_incidents_user_created
    ON client_incidents (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_client_incidents_status
    ON client_incidents (status);
