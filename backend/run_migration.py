import psycopg2

DATABASE_URL = "postgresql://neondb_owner:npg_lu5C1dFvpHeN@ep-still-sunset-a1v42bky-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

conn = psycopg2.connect(DATABASE_URL)
conn.autocommit = True
cur = conn.cursor()

cur.execute("ALTER TABLE conversation_sessions ADD COLUMN IF NOT EXISTS is_pinned INTEGER NOT NULL DEFAULT 0")
cur.execute("ALTER TABLE conversation_sessions ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0")

cur.close()
conn.close()
print("Migration done")
