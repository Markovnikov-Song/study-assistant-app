"""
Migration 014: 本地执行 calendar_events 添加 plan_id 字段。
用法: cd backend && python migrations/run_014.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_session_factory
from sqlalchemy import text

def main():
    sql_statements = [
        "ALTER TABLE calendar_events ADD COLUMN IF NOT EXISTS plan_id INTEGER",
        "CREATE INDEX IF NOT EXISTS idx_calendar_events_plan_id ON calendar_events (plan_id)",
        r"UPDATE calendar_events SET plan_id = NULLIF(REGEXP_REPLACE(notes, '^plan_id=(\d+).*$', '\1'), '')::INTEGER WHERE notes LIKE 'plan_id=%' AND plan_id IS NULL",
    ]

    db = get_session_factory()()
        for i, sql in enumerate(sql_statements, 1):
            print(f"[{i}/{len(sql_statements)}] 执行: {sql[:60]}...")
            try:
                db.execute(text(sql))
                db.commit()
                print(f"  ✅ 成功")
            except Exception as e:
                db.rollback()
                print(f"  ❌ 失败: {e}")
                return 1

    print("\n✅ Migration 014 完成")
    return 0

if __name__ == "__main__":
    sys.exit(main())
