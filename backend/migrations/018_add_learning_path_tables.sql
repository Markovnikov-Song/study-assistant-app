-- 018_add_learning_path_tables.sql
-- 学习路径和节点掌握度表

-- 学习路径表：预设的学科节点学习顺序和依赖关系
CREATE TABLE IF NOT EXISTS learning_paths (
    id SERIAL PRIMARY KEY,
    subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    node_ids JSONB NOT NULL DEFAULT '[]',
    prerequisites JSONB NOT NULL DEFAULT '{}',
    is_default INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_learning_paths_subject ON learning_paths(subject_id);

-- 节点掌握度表：记录用户对每个节点的掌握程度和练习数据
CREATE TABLE IF NOT EXISTS node_masteries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id INTEGER NOT NULL REFERENCES conversation_sessions(id) ON DELETE CASCADE,
    node_id VARCHAR(512) NOT NULL,
    mastery_level INTEGER NOT NULL DEFAULT 0,
    last_practiced_at TIMESTAMP WITH TIME ZONE,
    correct_count INTEGER NOT NULL DEFAULT 0,
    wrong_count INTEGER NOT NULL DEFAULT 0,
    lecture_read_duration INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_node_mastery UNIQUE (user_id, session_id, node_id)
);

CREATE INDEX IF NOT EXISTS idx_node_masteries_user_session ON node_masteries(user_id, session_id);