-- Migration 004: 添加思维导图图书馆相关表
-- mindmap_node_states: 节点点亮状态
-- node_lectures: 节点讲义内容

CREATE TABLE IF NOT EXISTS mindmap_node_states (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id  INTEGER NOT NULL REFERENCES conversation_sessions(id) ON DELETE CASCADE,
    node_id     VARCHAR(512) NOT NULL,
    is_lit      SMALLINT NOT NULL DEFAULT 1,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_node_state UNIQUE (user_id, session_id, node_id)
);

CREATE INDEX IF NOT EXISTS idx_node_states_user_session
    ON mindmap_node_states (user_id, session_id);

CREATE TABLE IF NOT EXISTS node_lectures (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id      INTEGER NOT NULL REFERENCES conversation_sessions(id) ON DELETE CASCADE,
    node_id         VARCHAR(512) NOT NULL,
    content         JSONB NOT NULL,
    resource_scope  JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_node_lecture UNIQUE (user_id, session_id, node_id)
);

CREATE INDEX IF NOT EXISTS idx_node_lectures_user_session
    ON node_lectures (user_id, session_id);
