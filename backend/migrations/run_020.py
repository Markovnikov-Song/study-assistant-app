"""Migration 020: add subjects.color_index for card accent colors."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text

from database import get_session_factory


def main() -> int:
    migration_path = os.path.join(
        os.path.dirname(__file__),
        "020_add_subject_color_index.sql",
    )
    with open(migration_path, "r", encoding="utf-8") as f:
        statements = [s.strip() for s in f.read().split(";") if s.strip()]

    db = get_session_factory()()
    try:
        for i, sql in enumerate(statements, 1):
            print(f"[{i}/{len(statements)}] {sql[:72]}...")
            db.execute(text(sql))
        db.commit()
        print("Migration 020 complete")
        return 0
    except Exception as exc:
        db.rollback()
        print(f"Migration 020 failed: {exc}")
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
