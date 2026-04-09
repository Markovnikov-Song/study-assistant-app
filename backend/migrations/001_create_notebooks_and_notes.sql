-- Migration: 001_create_notebooks_and_notes
-- Description: 创建 notebooks 和 notes 表，包含外键约束和索引
-- Requirements: 9.1, 9.2, 9.3, 9.4

-- ── notebooks 表 ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notebooks (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        VARCHAR(64) NOT NULL,
    is_system   BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned   BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 按用户查询笔记本的性能索引（需求 9.3）
CREATE INDEX IF NOT EXISTS idx_notebooks_user_id ON notebooks(user_id);

-- ── notes 表 ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notes (
    id                  SERIAL PRIMARY KEY,
    notebook_id         INTEGER NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
    subject_id          INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
    source_session_id   INTEGER REFERENCES conversation_sessions(id) ON DELETE SET NULL,
    source_message_id   INTEGER,
    role                VARCHAR(16) NOT NULL CHECK (role IN ('user', 'assistant')),
    original_content    TEXT NOT NULL,
    title               VARCHAR(64),
    outline             JSONB,
    imported_to_doc_id  INTEGER REFERENCES documents(id) ON DELETE SET NULL,
    sources             JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 按笔记本和学科栏查询的复合索引（需求 9.4）
CREATE INDEX IF NOT EXISTS idx_notes_notebook_subject ON notes(notebook_id, subject_id);
