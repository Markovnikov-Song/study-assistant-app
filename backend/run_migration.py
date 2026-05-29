import os

import psycopg2

DATABASE_URL = os.environ["DATABASE_URL"]

conn = psycopg2.connect(DATABASE_URL)
conn.autocommit = True
cur = conn.cursor()

cur.execute("ALTER TABLE conversation_sessions ADD COLUMN IF NOT EXISTS is_pinned INTEGER NOT NULL DEFAULT 0")
cur.execute("ALTER TABLE conversation_sessions ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0")

cur.close()
conn.close()
print("Migration done")
