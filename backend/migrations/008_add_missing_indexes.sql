-- Migration 008: 添加缺失的数据库索引
-- 修复 ORM 与实际索引不一致的问题

-- 1. 修复 hint_suggestions 表：添加 hint_type 到唯一约束
-- 如果表已存在且缺少 hint_type 字段或唯一约束，需要先执行 ALTER TABLE
-- 对于新表，ORM 会正确创建

-- 2. chunks 表添加 subject_id 索引（支持 RAG 检索）
CREATE INDEX IF NOT EXISTS idx_chunks_subject_id ON chunks(subject_id);

-- 3. documents 表添加 user_id 和 subject_id 索引
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_subject_id ON documents(subject_id);

-- 4. past_exam_files 表添加 user_id 和 subject_id 索引
CREATE INDEX IF NOT EXISTS idx_past_exam_files_user_id ON past_exam_files(user_id);
CREATE INDEX IF NOT EXISTS idx_past_exam_files_subject_id ON past_exam_files(subject_id);

-- 5. past_exam_questions 表添加 subject_id 索引
CREATE INDEX IF NOT EXISTS idx_past_exam_questions_subject_id ON past_exam_questions(subject_id);

-- 6. conversation_sessions 表添加 user_id 索引和复合索引
CREATE INDEX IF NOT EXISTS idx_conversation_sessions_user_id ON conversation_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_conversation_sessions_user_created ON conversation_sessions(user_id, created_at DESC);

-- 7. conversation_history 表添加 session_id 和 created_at 索引
CREATE INDEX IF NOT EXISTS idx_conversation_history_session_id ON conversation_history(session_id);
CREATE INDEX IF NOT EXISTS idx_conversation_history_created_at ON conversation_history(created_at);

-- 8. subjects 表添加 user_id 索引
CREATE INDEX IF NOT EXISTS idx_subjects_user_id ON subjects(user_id);

-- 9. 修复 hint_suggestions 表的约束（如果表已存在）
-- 添加 UNIQUE 约束使用户不能重复插入同一用户同一学科同一类型的提示
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'hint_suggestions' 
        AND column_name = 'hint_type'
    ) THEN
        -- 表已存在且包含 hint_type，添加唯一约束
        ALTER TABLE hint_suggestions ADD CONSTRAINT uq_hint_suggestion 
        UNIQUE (user_id, subject_id, hint_type);
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        NULL;  -- 约束已存在，忽略
END $$;
