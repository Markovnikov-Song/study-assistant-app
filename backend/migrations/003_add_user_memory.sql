-- Migration 003: 添加用户学习记忆/画像表
-- 如果已通过 init_db() 自动建表则此脚本无副作用（IF NOT EXISTS）

CREATE TABLE IF NOT EXISTS user_memory (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id  INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
    memory      JSONB NOT NULL DEFAULT '{}',
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_memory_user_subject
    ON user_memory (user_id, subject_id);

-- 用于按用户快速查询
CREATE INDEX IF NOT EXISTS idx_user_memory_user_id
    ON user_memory (user_id);
