"""
Migration 015: 为用户表添加四个模型的完整配置字段
运行方式：在 backend 目录下执行 python run_migration_015.py
"""
import os
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

import psycopg2

DATABASE_URL = os.environ["DATABASE_URL"]

conn = psycopg2.connect(DATABASE_URL)
conn.autocommit = True
cur = conn.cursor()

migrations = [
    # 语言模型新增模型名
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_llm_model TEXT",
    # 视觉模型新增模型名
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_vision_model TEXT",
    # 向量化模型（三要素）
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_embedding_base_url TEXT",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_embedding_api_key TEXT",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_embedding_model TEXT",
    # 重排序模型（三要素）
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_reranker_base_url TEXT",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_reranker_api_key TEXT",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_reranker_model TEXT",
]

for sql in migrations:
    print(f"执行: {sql}")
    cur.execute(sql)

cur.close()
conn.close()
print("\nMigration 015 完成 ✓")
