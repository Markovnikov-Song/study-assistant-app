"""
跑 migration 009 + 010：
  - 009: notes 表添加 mastery_score / review_count / last_reviewed_at / mistake_category / mastery_history
  - 010: notes 表添加 review_card_id / node_id / question_text / user_answer / correct_answer
"""
import psycopg2

DATABASE_URL = (
    "postgresql://neondb_owner:npg_lu5C1dFvpHeN"
    "@ep-still-sunset-a1v42bky-pooler.ap-southeast-1.aws.neon.tech"
    "/neondb?sslmode=require"
)

SQLS = [
    # ── migration 009 ─────────────────────────────────────────────────────────
    ("notes.mastery_score",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS mastery_score SMALLINT NOT NULL DEFAULT 0"),
    ("notes.review_count",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS review_count INTEGER NOT NULL DEFAULT 0"),
    ("notes.last_reviewed_at",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS last_reviewed_at TIMESTAMPTZ"),
    ("notes.mistake_category",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS mistake_category VARCHAR(32)"),
    ("notes.mastery_history",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS mastery_history JSONB"),

    # ── migration 010 ─────────────────────────────────────────────────────────
    ("notes.review_card_id",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS review_card_id INTEGER"),
    ("notes.node_id",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS node_id VARCHAR(512)"),
    ("notes.question_text",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS question_text TEXT"),
    ("notes.user_answer",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS user_answer TEXT"),
    ("notes.correct_answer",
     "ALTER TABLE notes ADD COLUMN IF NOT EXISTS correct_answer TEXT"),

    # ── 索引 ──────────────────────────────────────────────────────────────────
    ("idx_notes_review_card_id",
     "CREATE INDEX IF NOT EXISTS idx_notes_review_card_id ON notes(review_card_id)"),
    ("idx_notes_node_id",
     "CREATE INDEX IF NOT EXISTS idx_notes_node_id ON notes(node_id)"),
    ("idx_notes_mistake_status",
     "CREATE INDEX IF NOT EXISTS idx_notes_mistake_status ON notes(mistake_status)"),
    ("idx_notes_subject_id",
     "CREATE INDEX IF NOT EXISTS idx_notes_subject_id ON notes(subject_id)"),
]

conn = psycopg2.connect(DATABASE_URL)
conn.autocommit = True
cur = conn.cursor()

for name, sql in SQLS:
    try:
        cur.execute(sql)
        print(f"  ✓ {name}")
    except Exception as e:
        print(f"  ✗ {name}: {e}")

cur.close()
conn.close()
print("\n全部完成")
