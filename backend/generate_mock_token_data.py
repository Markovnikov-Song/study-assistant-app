"""
生成模拟 Token 使用数据

用于测试 AI 使用强度统计页面

运行方式：
    python backend/generate_mock_token_data.py
"""
import os
import sys
import random
from datetime import datetime, timedelta
from sqlalchemy import text

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_engine, TokenUsageLog, UserTokenQuota, get_session
from backend.services.token_service import TIER_CONFIG


def generate_mock_data(user_id: int, days: int = 30):
    """生成模拟 Token 使用数据"""
    
    engine = get_engine()
    
    with engine.connect() as conn:
        # 检查用户配额是否存在
        result = conn.execute(
            text(f"SELECT id FROM user_token_quota WHERE user_id = {user_id}")
        )
        if not result.fetchone():
            # 创建默认配额
            with get_session() as session:
                quota = UserTokenQuota(
                    user_id=user_id,
                    tier="free",
                    quota_daily=TIER_CONFIG["free"]["daily_quota"],
                    quota_monthly=TIER_CONFIG["free"]["monthly_quota"],
                    rate_limit_per_min=TIER_CONFIG["free"]["rate_limit_per_min"],
                    rate_limit_per_hour=TIER_CONFIG["free"]["rate_limit_per_hour"],
                    payg_enabled=1,
                    used_today=0,
                    used_this_month=0,
                    bonus_tokens=0,
                    bonus_used=0,
                    total_tokens_all_time=0,
                    total_cost_all_time=0,
                )
                session.add(quota)
                session.commit()
            print(f"  [OK] 为用户 {user_id} 创建了默认配额")
        
        # 生成模拟使用记录
        count = 0
        now = datetime.now()
        
        with get_session() as session:
            for day_offset in range(days):
                date = now - timedelta(days=day_offset)
                
                # 每天 0-8 次请求
                daily_requests = random.randint(0, 8)
                
                for _ in range(daily_requests):
                    # 随机时间点
                    request_time = date.replace(
                        hour=random.randint(8, 23),
                        minute=random.randint(0, 59),
                        second=random.randint(0, 59)
                    )
                    
                    # 随机 endpoint
                    endpoint = random.choice(["chat", "chat", "chat", "solve", "mindmap"])
                    
                    # 随机 token 数
                    input_tokens = random.randint(100, 2000)
                    output_tokens = random.randint(50, 1500)
                    
                    log = TokenUsageLog(
                        user_id=user_id,
                        endpoint=endpoint,
                        model_name="gpt-3.5-turbo",
                        input_tokens=input_tokens,
                        output_tokens=output_tokens,
                        total_tokens=input_tokens + output_tokens,
                        api_cost=0,  # 当前费用为0
                        request_id=f"mock_{count}_{request_time.timestamp()}",
                        created_at=request_time,
                    )
                    session.add(log)
                    count += 1
                    
                    # 更新配额
                    session.execute(
                        text(f"UPDATE user_token_quota SET "
                        f"used_today = used_today + {input_tokens + output_tokens}, "
                        f"used_this_month = used_this_month + {input_tokens + output_tokens}, "
                        f"total_tokens_all_time = total_tokens_all_time + {input_tokens + output_tokens} "
                        f"WHERE user_id = {user_id}")
                    )
            
            session.commit()
        
        print(f"\n生成完成！")
        print(f"   - 用户 ID: {user_id}")
        print(f"   - 生成天数: {days}")
        print(f"   - 生成记录数: {count}")
        print(f"\n现在可以刷新页面查看模拟数据了")


if __name__ == "__main__":
    print("=" * 50)
    print("生成模拟 Token 使用数据")
    print("=" * 50)
    
    # 获取用户 ID
    user_id_str = input("\n请输入要生成数据的用户 ID (直接回车默认为 1): ").strip()
    if not user_id_str:
        user_id = 1
    else:
        try:
            user_id = int(user_id_str)
        except ValueError:
            print("无效的用户 ID，默认使用 1")
            user_id = 1
    
    # 获取天数
    days_str = input("请输入生成天数 (直接回车默认为 30): ").strip()
    if not days_str:
        days = 30
    else:
        try:
            days = int(days_str)
        except ValueError:
            print("无效的天数，默认使用 30")
            days = 30
    
    print(f"\n正在为用户 {user_id} 生成最近 {days} 天的模拟数据...")
    generate_mock_data(user_id, days)
