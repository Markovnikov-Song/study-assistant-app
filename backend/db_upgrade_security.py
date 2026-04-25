#!/usr/bin/env python3
"""数据库升级脚本 - 添加用户角色支持"""

import psycopg2

def main():
    # Neon 连接字符串
    db_url = 'postgresql://neondb_owner:npg_lu5C1dFvpHeN@ep-still-sunset-a1v42bky-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require'

    print('Connecting to Neon...')
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()

    # 检查 users 表结构
    cur.execute("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'role'
    """)
    result = cur.fetchone()

    if result:
        print(f'role column exists: {result}')
    else:
        print('Adding role column...')
        cur.execute("ALTER TABLE users ADD COLUMN role VARCHAR(16) DEFAULT 'user'")
        conn.commit()
        print('role column added!')

    # 设置第一个用户为管理员
    cur.execute('SELECT id, username FROM users WHERE id = 1')
    user = cur.fetchone()
    if user:
        cur.execute("UPDATE users SET role = 'admin' WHERE id = 1")
        conn.commit()
        print(f'User {user[1]} (ID:1) set as admin')
    else:
        print('No user with ID 1 found')

    # 显示当前状态
    cur.execute('SELECT id, username, role FROM users LIMIT 10')
    print()
    print('Current users:')
    print('-' * 40)
    for row in cur.fetchall():
        print(f'  ID:{row[0]:3} | {row[1]:20} | {row[2]}')

    cur.close()
    conn.close()
    print()
    print('Database upgrade complete!')

if __name__ == '__main__':
    main()
