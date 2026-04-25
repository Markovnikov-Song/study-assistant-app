"""
迁移 011：Token计费系统

运行方式：
    python run_migration_011.py

注意：确保先运行之前的迁移
"""

import os
import sys

# 添加 backend 目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run_migration():
    """执行迁移"""
    from sqlalchemy import text
    from database import get_engine
    from backend_config import get_config
    
    # 确保配置加载
    cfg = get_config()
    
    # 读取 SQL 文件
    migration_file = os.path.join(
        os.path.dirname(__file__),
        "migrations",
        "011_add_token_tables.sql"
    )
    
    with open(migration_file, "r", encoding="utf-8") as f:
        sql = f.read()
    
    # 分割并执行每个语句
    statements = []
    current = []
    in_function = False
    in_trigger = False
    
    for line in sql.split("\n"):
        stripped = line.strip()
        
        # 跳过注释
        if stripped.startswith("--") or not stripped:
            continue
        
        # 检测函数/触发器定义
        if "CREATE OR REPLACE FUNCTION" in stripped or "CREATE FUNCTION" in stripped:
            in_function = True
        if "CREATE TRIGGER" in stripped:
            in_trigger = True
        
        current.append(line)
        
        # 函数结束检测
        if in_function and stripped.startswith("$$ LANGUAGE"):
            statements.append("\n".join(current))
            current = []
            in_function = False
        
        # 触发器结束检测
        if in_trigger and stripped.startswith("'"):
            statements.append("\n".join(current))
            current = []
            in_trigger = False
        
        # 普通语句结束
        if not in_function and not in_trigger and stripped.endswith(";"):
            statements.append("\n".join(current))
            current = []
    
    # 执行
    engine = get_engine()
    
    print("开始执行迁移 011...")
    
    success_count = 0
    fail_count = 0
    
    for i, stmt in enumerate(statements):
        if not stmt.strip():
            continue
        with engine.connect() as conn:
            try:
                conn.execute(text(stmt))
                conn.commit()
                print(f"  [OK] 语句 {i+1}/{len(statements)} 执行成功")
                success_count += 1
            except Exception as e:
                conn.rollback()
                err_short = str(e).split('\n')[0]
                print(f"  [SKIP] 语句 {i+1}/{len(statements)}: {err_short}")
                fail_count += 1
    
    print(f"\n迁移 011 完成！ 成功: {success_count}，跳过/已存在: {fail_count}")
    print("\n已创建的表：")
    print("  - token_usage_log (Token使用日志)")
    print("  - user_token_quota (用户配额)")
    print("  - tier_definitions (档位定义)")
    print("  - user_subscriptions (订阅记录)")
    print("  - token_bills (月度账单)")
    print("  - token_daily_snapshot (每日快照)")


if __name__ == "__main__":
    run_migration()

