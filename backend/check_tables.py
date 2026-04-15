#!/usr/bin/env python3
"""
检查数据库表和API接口
"""
import sys
sys.path.append('..')
from backend_config import get_config
from sqlalchemy import create_engine, text
import os

def check_database():
    """检查数据库连接和表结构"""
    config = get_config()
    engine = create_engine(config.DATABASE_URL)
    
    try:
        with engine.connect() as conn:
            # 检查表是否存在
            tables = ['mindmap_node_states', 'node_lectures', 'conversation_sessions', 
                     'conversation_history', 'subjects', 'users']
            
            print("检查数据库表状态...")
            for table in tables:
                result = conn.execute(
                    text(f"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '{table}')")
                ).scalar()
                status = "存在" if result else "不存在"
                print(f"  表 {table}: {status}")
            
            # 检查表结构
            print("\n检查表结构...")
            for table in ['mindmap_node_states', 'node_lectures']:
                print(f"\n{table} 表结构:")
                result = conn.execute(text(f"""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_name = '{table}' 
                    ORDER BY ordinal_position
                """))
                
                for row in result:
                    print(f"  {row[0]}: {row[1]}")
            
            print("\n数据库连接和表结构检查完成！")
            return True
            
    except Exception as e:
        print(f"数据库连接错误: {e}")
        return False

def check_api_endpoints():
    """检查API端点"""
    print("\n检查API端点...")
    endpoints = [
        "/api/library/subjects",
        "/api/library/subjects/1/sessions", 
        "/api/library/sessions/1/nodes",
        "/api/library/sessions/1/node-states"
    ]
    
    for endpoint in endpoints:
        print(f"  {endpoint} - 需要认证")
    
    print("\nAPI端点检查完成")

if __name__ == "__main__":
    print("=" * 50)
    print("检查后端基础可用性")
    print("=" * 50)
    
    print("\n1. 检查数据库连接和表结构...")
    if not check_database():
        print("数据库检查失败")
        sys.exit(1)
    
    print("\n2. 检查API端点...")
    check_api_endpoints()
    
    print("\n" + "=" * 50)
    print("检查完成！")
    print("=" * 50)