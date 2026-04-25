-- Migration 014: calendar_events 添加 plan_id 结构化关联
-- 替代原来通过 notes 文本存储 plan_id 的方式

ALTER TABLE calendar_events
    ADD COLUMN IF NOT EXISTS plan_id INTEGER;

-- 索引：按 plan_id 快速查询
CREATE INDEX IF NOT EXISTS idx_calendar_events_plan_id
    ON calendar_events (plan_id);

-- 数据迁移：从 notes 文本中提取已有的 plan_id
-- notes 格式: "plan_id=123"
UPDATE calendar_events
SET plan_id = NULLIF(REGEXP_REPLACE(notes, '^plan_id=(\d+).*$', '\1'), '')::INTEGER
WHERE notes LIKE 'plan_id=%'
  AND plan_id IS NULL;
