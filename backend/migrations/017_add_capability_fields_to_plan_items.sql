-- Migration 017: plan_items 增加能力应用绑定字段
-- 让学习计划条目从纯文本任务升级为可执行的能力任务。

ALTER TABLE plan_items
    ADD COLUMN IF NOT EXISTS capability_id VARCHAR(128);

ALTER TABLE plan_items
    ADD COLUMN IF NOT EXISTS capability_params JSONB DEFAULT '{}'::jsonb;

ALTER TABLE plan_items
    ADD COLUMN IF NOT EXISTS completion_contract JSONB DEFAULT '{}'::jsonb;

ALTER TABLE plan_items
    ADD COLUMN IF NOT EXISTS completion_result JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_plan_items_capability_id
    ON plan_items (capability_id);
