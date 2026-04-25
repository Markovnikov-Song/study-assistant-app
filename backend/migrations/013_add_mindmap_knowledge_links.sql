-- Migration 013: 添加知识关联图表
-- mindmap_knowledge_links: 存储思维导图节点间的跨节点关联

CREATE TABLE IF NOT EXISTS mindmap_knowledge_links (
    id                  SERIAL PRIMARY KEY,
    user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id          INTEGER NOT NULL REFERENCES conversation_sessions(id) ON DELETE CASCADE,
    source_node_id      VARCHAR(512) NOT NULL,
    target_node_id      VARCHAR(512) NOT NULL,
    source_node_text    VARCHAR(512) NOT NULL,
    target_node_text    VARCHAR(512) NOT NULL,
    link_type           VARCHAR(32) NOT NULL,  -- causal/dependency/contrast/evolution
    rationale           VARCHAR(200),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_knowledge_link UNIQUE (user_id, session_id, source_node_id, target_node_id)
);

CREATE INDEX IF NOT EXISTS idx_knowledge_links_user_session
    ON mindmap_knowledge_links (user_id, session_id);
