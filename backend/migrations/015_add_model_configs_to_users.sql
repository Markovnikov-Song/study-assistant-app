-- Migration 015: 为用户表添加四个模型的完整配置字段
-- 每个模型三要素：base_url + api_key + model_name
-- 涵盖：语言模型、视觉模型（OCR）、向量化模型（Embedding）、重排序模型（Reranker）

ALTER TABLE users
    -- 语言模型（已有 base_url 和 api_key，新增 model_name）
    ADD COLUMN IF NOT EXISTS custom_llm_model       TEXT,

    -- 视觉模型（已有 base_url 和 api_key，新增 model_name）
    ADD COLUMN IF NOT EXISTS custom_vision_model    TEXT,

    -- 向量化模型（全新三要素）
    ADD COLUMN IF NOT EXISTS custom_embedding_base_url  TEXT,
    ADD COLUMN IF NOT EXISTS custom_embedding_api_key   TEXT,
    ADD COLUMN IF NOT EXISTS custom_embedding_model     TEXT,

    -- 重排序模型（全新三要素）
    ADD COLUMN IF NOT EXISTS custom_reranker_base_url   TEXT,
    ADD COLUMN IF NOT EXISTS custom_reranker_api_key    TEXT,
    ADD COLUMN IF NOT EXISTS custom_reranker_model      TEXT;
