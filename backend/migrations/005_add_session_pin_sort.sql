-- Migration: 005_add_session_pin_sort
-- 给 conversation_sessions 表添加置顶和排序字段（仅 mindmap 类型使用）
ALTER TABLE conversation_sessions ADD COLUMN IF NOT EXISTS is_pinned INTEGER NOT NULL DEFAULT 0;
ALTER TABLE conversation_sessions ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;
