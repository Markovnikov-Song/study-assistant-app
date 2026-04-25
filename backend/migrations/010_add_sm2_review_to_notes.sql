-- 迁移 010: 扩展 Note 表添加 SM-2 关联字段
-- 目的：打通 练习 → 错题本 → 复盘 → SM-2 完整闭环
-- 时间: 2026-04-24

-- 添加关联的 SM-2 复习卡片外键
ALTER TABLE notes 
ADD COLUMN IF NOT EXISTS review_card_id INTEGER REFERENCES review_cards(id) ON DELETE SET NULL;

-- 添加练习题目相关字段
ALTER TABLE notes 
ADD COLUMN IF NOT EXISTS node_id VARCHAR(512);

ALTER TABLE notes 
ADD COLUMN IF NOT EXISTS question_text TEXT;

ALTER TABLE notes 
ADD COLUMN IF NOT EXISTS user_answer TEXT;

ALTER TABLE notes 
ADD COLUMN IF NOT EXISTS correct_answer TEXT;

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_notes_review_card_id ON notes(review_card_id);
CREATE INDEX IF NOT EXISTS idx_notes_node_id ON notes(node_id);
CREATE INDEX IF NOT EXISTS idx_notes_mistake_status ON notes(mistake_status);
CREATE INDEX IF NOT EXISTS idx_notes_subject_id ON notes(subject_id);
