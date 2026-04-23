import psycopg2

DATABASE_URL = (
    "postgresql://neondb_owner:npg_lu5C1dFvpHeN"
    "@ep-still-sunset-a1v42bky-pooler.ap-southeast-1.aws.neon.tech"
    "/neondb?sslmode=require"
)

with open("migrations/007_add_calendar_tables.sql", "r", encoding="utf-8") as f:
    sql = f.read()

conn = psycopg2.connect(DATABASE_URL)
conn.autocommit = True
cur = conn.cursor()
cur.execute(sql)
cur.close()
conn.close()
print("Migration 007 done — calendar_events, calendar_routines, study_sessions 表已创建")
