-- Migration 016: subject-scoped material knowledge bases and document processing metadata.

ALTER TABLE documents
    ADD COLUMN IF NOT EXISTS processing_stage VARCHAR(32) NOT NULL DEFAULT 'queued',
    ADD COLUMN IF NOT EXISTS progress SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS parser_backend VARCHAR(64),
    ADD COLUMN IF NOT EXISTS chunk_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS outline JSONB,
    ADD COLUMN IF NOT EXISTS mindmap_ready BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE chunks
    ADD COLUMN IF NOT EXISTS heading_path VARCHAR(1024),
    ADD COLUMN IF NOT EXISTS token_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_secondary BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS subject_knowledge_bases (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL DEFAULT 'empty',
    document_count INTEGER NOT NULL DEFAULT 0,
    chunk_count INTEGER NOT NULL DEFAULT 0,
    outline JSONB,
    mindmap_ready BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_subject_knowledge_base UNIQUE (user_id, subject_id)
);

CREATE INDEX IF NOT EXISTS idx_subject_kb_user_subject
    ON subject_knowledge_bases (user_id, subject_id);

CREATE INDEX IF NOT EXISTS idx_documents_user_subject_status
    ON documents (user_id, subject_id, status);

CREATE INDEX IF NOT EXISTS idx_chunks_subject_document
    ON chunks (subject_id, document_id, chunk_index);
