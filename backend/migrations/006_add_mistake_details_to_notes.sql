-- Migration 006: 为错题笔记添加结构化的错题元数据字段
-- 包括章节、错误类型、用户答案、正确答案、分析和最后复盘时间。

ALTER TABLE notes ADD COLUMN IF NOT EXISTS mistake_details JSONB;
