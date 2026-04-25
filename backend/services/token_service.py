"""
Token计费服务：Token统计、配额管理、限流控制

功能：
- Token使用统计与记录
- 用户配额管理
- 滑动窗口限流
- 档位升级/降级
- 超额计费计算
"""

from __future__ import annotations

from datetime import datetime, timedelta, date
from typing import Optional, Tuple
from dataclasses import dataclass
from functools import lru_cache
import threading

# ============================================================================
# 档位定义（内存缓存，与数据库 tier_definitions 表同步）
# ============================================================================

TIER_CONFIG = {
    "free": {
        "name": "免费版",
        "price_monthly": 0,
        "daily_quota": 50_000,
        "monthly_quota": 0,
        "rate_limit_per_min": 10,
        "rate_limit_per_hour": 100,
        "payg_enabled": True,
    },
    "mini": {
        "name": "轻量版",
        "price_monthly": 990,  # 放大100倍
        "daily_quota": 100_000,
        "monthly_quota": 1_000_000,
        "rate_limit_per_min": 30,
        "rate_limit_per_hour": 300,
        "payg_enabled": True,
    },
    "standard": {
        "name": "标准版",
        "price_monthly": 2990,
        "daily_quota": 300_000,
        "monthly_quota": 5_000_000,
        "rate_limit_per_min": 60,
        "rate_limit_per_hour": 600,
        "payg_enabled": True,
    },
    "plus": {
        "name": "增强版",
        "price_monthly": 5990,
        "daily_quota": 800_000,
        "monthly_quota": 15_000_000,
        "rate_limit_per_min": 120,
        "rate_limit_per_hour": 1200,
        "payg_enabled": True,
    },
    "enterprise": {
        "name": "企业版",
        "price_monthly": 19900,
        "daily_quota": 2_000_000,
        "monthly_quota": 50_000_000,
        "rate_limit_per_min": 300,
        "rate_limit_per_hour": 3000,
        "payg_enabled": False,
    },
}

# 超额计费率（按量付费价格，元/百万tokens）
# 当前设为0，即所有费用为0
PAYG_RATE_PER_MILLION = 0  # 元 / 1M tokens


# ============================================================================
# 模型成本配置
# ============================================================================

MODEL_COSTS = {
    # 格式: model_name -> (input_cost_per_1k, output_cost_per_1k), 单位：元/1K tokens
    # 当前全部设为0
    "default": (0.0, 0.0),
}


# ============================================================================
# 异常定义
# ============================================================================

class TokenQuotaExceeded(Exception):
    """Token配额超限"""
    def __init__(self, quota_type: str, limit: int, used: int, remaining: int):
        self.quota_type = quota_type  # "daily" / "monthly"
        self.limit = limit
        self.used = used
        self.remaining = remaining
        super().__init__(f"{quota_type}配额超限: 已用{used}/{limit}")


class RateLimitExceeded(Exception):
    """请求频率超限"""
    def __init__(self, window: str, limit: int, retry_after: int):
        self.window = window
        self.limit = limit
        self.retry_after = retry_after
        super().__init__(f"请求过于频繁，请在{retry_after}秒后重试")


class UserBlockedException(Exception):
    """用户被封禁"""
    pass


# ============================================================================
# 数据类
# ============================================================================

@dataclass
class TokenUsage:
    """Token使用记录"""
    input_tokens: int
    output_tokens: int
    total_tokens: int
    api_cost: int  # 放大1000000倍
    model_name: str
    endpoint: str


@dataclass
class UserQuota:
    """用户配额信息"""
    user_id: int
    tier: str
    tier_name: str
    quota_daily: int
    quota_monthly: int
    used_today: int
    used_this_month: int
    bonus_tokens: int
    bonus_used: int
    remaining_today: int
    remaining_monthly: int
    remaining_bonus: int
    daily_usage_percent: float
    monthly_usage_percent: float
    is_blocked: bool
    rate_limit_per_min: int
    rate_limit_per_hour: int
    total_tokens_all_time: int
    total_cost_all_time: float  # 实际金额
    price_monthly: float  # 实际金额


# ============================================================================
# Token服务
# ============================================================================

class TokenService:
    """
    Token计费服务
    
    使用方式：
    service = TokenService()
    
    # 记录使用
    usage = service.record_usage(user_id, input_tokens=500, output_tokens=800, endpoint="chat")
    
    # 获取配额
    quota = service.get_quota(user_id)
    
    # 检查限流
    allowed, remaining = service.check_rate_limit(user_id)
    """
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._init()
        return cls._instance
    
    def _init(self):
        """初始化"""
        self._rate_cache: dict[int, dict] = {}  # user_id -> {minute: (time, count), hour: (time, count)}
        self._lock_rate = threading.Lock()
    
    # --------------------------------------------------------------------------
    # Token计算
    # --------------------------------------------------------------------------
    
    def calculate_cost(
        self,
        model_name: str,
        input_tokens: int,
        output_tokens: int
    ) -> int:
        """
        计算API费用
        
        Args:
            model_name: 模型名称
            input_tokens: 输入token数
            output_tokens: 输出token数
            
        Returns:
            费用（放大1000000倍存储）
        """
        # 查找模型定价
        base_model = model_name.lower()
        cost = MODEL_COSTS.get("default")
        
        for key, value in MODEL_COSTS.items():
            if key != "default" and key in base_model:
                cost = value
                break
        
        if cost is None:
            cost = MODEL_COSTS["default"]
        
        input_cost = input_tokens * cost[0] / 1000
        output_cost = output_tokens * cost[1] / 1000
        
        # 返回放大1000000倍的结果
        return int((input_cost + output_cost) * 1_000_000)
    
    def estimate_tokens(self, text: str) -> int:
        """
        估算文本的token数量
        
        简化估算：
        - 中文：约1.5字符/token
        - 英文：约4字符/token
        """
        if not text:
            return 0
        
        chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
        other_chars = len(text) - chinese_chars
        
        return int(chinese_chars / 1.5 + other_chars / 4)
    
    def estimate_from_messages(self, messages: list[dict], response_text: str = "") -> Tuple[int, int]:
        """
        从消息列表估算token数
        
        Returns:
            (input_tokens, output_tokens)
        """
        # 估算输入
        input_parts = []
        for msg in messages:
            content = msg.get("content", "")
            if isinstance(content, str):
                input_parts.append(content)
            elif isinstance(content, list):
                for item in content:
                    if isinstance(item, dict) and item.get("type") == "text":
                        input_parts.append(item.get("text", ""))
        
        input_text = " ".join(input_parts)
        input_tokens = self.estimate_tokens(input_text)
        
        # 估算输出
        output_tokens = self.estimate_tokens(response_text)
        
        return input_tokens, output_tokens
    
    # --------------------------------------------------------------------------
    # 配额管理
    # --------------------------------------------------------------------------
    
    def get_quota(self, user_id: int) -> UserQuota:
        """
        获取用户配额信息
        """
        from database import UserTokenQuota, TierDefinition
        
        with self._get_db_session() as db:
            quota = db.query(UserTokenQuota).filter_by(user_id=user_id).first()
            
            if not quota:
                # 自动创建免费档
                quota = self._create_default_quota(db, user_id)
            
            tier_config = TIER_CONFIG.get(quota.tier, TIER_CONFIG["free"])
            tier_def = db.query(TierDefinition).filter_by(tier=quota.tier).first()
            
            remaining_today = max(0, quota.quota_daily - quota.used_today)
            remaining_monthly = max(0, quota.quota_monthly - quota.used_this_month)
            remaining_bonus = max(0, quota.bonus_tokens - quota.bonus_used)
            
            return UserQuota(
                user_id=user_id,
                tier=quota.tier,
                tier_name=tier_config["name"],
                quota_daily=quota.quota_daily,
                quota_monthly=quota.quota_monthly,
                used_today=quota.used_today,
                used_this_month=quota.used_this_month,
                bonus_tokens=quota.bonus_tokens,
                bonus_used=quota.bonus_used,
                remaining_today=remaining_today,
                remaining_monthly=remaining_monthly,
                remaining_bonus=remaining_bonus,
                daily_usage_percent=round(quota.used_today / quota.quota_daily * 100, 1) if quota.quota_daily > 0 else 100.0,
                monthly_usage_percent=round(quota.used_this_month / quota.quota_monthly * 100, 1) if quota.quota_monthly > 0 else 0.0,
                is_blocked=quota.is_blocked == 1,
                rate_limit_per_min=quota.rate_limit_per_min,
                rate_limit_per_hour=quota.rate_limit_per_hour,
                total_tokens_all_time=quota.total_tokens_all_time,
                total_cost_all_time=quota.total_cost_all_time / 1_000_000 if quota.total_cost_all_time else 0.0,
                price_monthly=tier_config["price_monthly"] / 100 if tier_config else 0.0,
            )
    
    def _create_default_quota(self, db, user_id: int) -> UserTokenQuota:
        """创建默认配额"""
        from database import UserTokenQuota
        
        quota = UserTokenQuota(
            user_id=user_id,
            tier="free",
            quota_daily=TIER_CONFIG["free"]["daily_quota"],
            quota_monthly=TIER_CONFIG["free"]["monthly_quota"],
            rate_limit_per_min=TIER_CONFIG["free"]["rate_limit_per_min"],
            rate_limit_per_hour=TIER_CONFIG["free"]["rate_limit_per_hour"],
            payg_enabled=1,
        )
        db.add(quota)
        db.flush()
        return quota
    
    def check_quota(
        self,
        user_id: int,
        tokens: int,
        allow_bonus: bool = True
    ) -> Tuple[bool, str]:
        """
        检查配额是否足够
        
        Args:
            user_id: 用户ID
            tokens: 需要的token数量
            allow_bonus: 是否允许使用bonus
            
        Returns:
            (是否通过, 失败原因)
        """
        quota = self.get_quota(user_id)
        
        # 检查封禁
        if quota.is_blocked:
            return False, "账号已被封禁"
        
        # 检查每日配额
        if tokens > quota.remaining_today:
            # 尝试用bonus
            if allow_bonus and quota.remaining_bonus >= tokens:
                return True, ""  # bonus足够
            return False, f"每日Token配额不足 (需要{tokens}, 剩余{quota.remaining_today})"
        
        return True, ""
    
    def check_rate_limit(self, user_id: int) -> Tuple[bool, int]:
        """
        检查请求频率限制
        
        Returns:
            (是否通过, 剩余可请求数)
        """
        quota = self.get_quota(user_id)
        now = datetime.now()
        
        with self._lock_rate:
            if user_id not in self._rate_cache:
                self._rate_cache[user_id] = {}
            
            cache = self._rate_cache[user_id]
            
            # 检查分钟级限流
            minute_key = "minute"
            if minute_key in cache:
                start, count = cache[minute_key]
                if (now - start).total_seconds() < 60:
                    if count >= quota.rate_limit_per_min:
                        return False, 0
                    cache[minute_key] = (start, count + 1)
                else:
                    cache[minute_key] = (now, 1)
            else:
                cache[minute_key] = (now, 1)
            
            # 检查小时级限流
            hour_key = "hour"
            if hour_key in cache:
                start, count = cache[hour_key]
                if (now - start).total_seconds() < 3600:
                    if count >= quota.rate_limit_per_hour:
                        return False, 0
                    cache[hour_key] = (start, count + 1)
                else:
                    cache[hour_key] = (now, 1)
            else:
                cache[hour_key] = (now, 1)
            
            # 清理过期缓存
            self._cleanup_cache(user_id, now)
            
            remaining = quota.rate_limit_per_min - cache.get(minute_key, (now, 0))[1]
            return True, max(0, remaining)
    
    def _cleanup_cache(self, user_id: int, now: datetime):
        """清理过期缓存"""
        cache = self._rate_cache.get(user_id, {})
        
        for key in list(cache.keys()):
            start, count = cache[key]
            if key == "minute" and (now - start).total_seconds() >= 60:
                del cache[key]
            elif key == "hour" and (now - start).total_seconds() >= 3600:
                del cache[key]
    
    # --------------------------------------------------------------------------
    # 记录使用
    # --------------------------------------------------------------------------
    
    def record_usage(
        self,
        user_id: int,
        input_tokens: int,
        output_tokens: int,
        endpoint: str = "chat",
        model_name: str = "",
        session_id: Optional[int] = None,
        request_id: Optional[str] = None,
    ) -> TokenUsage:
        """
        记录Token使用
        
        Args:
            user_id: 用户ID
            input_tokens: 输入token数
            output_tokens: 输出token数
            endpoint: 端点类型
            model_name: 模型名称
            session_id: 会话ID
            request_id: 请求追踪ID
            
        Returns:
            TokenUsage记录
        """
        from database import TokenUsageLog, UserTokenQuota
        
        total_tokens = input_tokens + output_tokens
        api_cost = self.calculate_cost(model_name or "default", input_tokens, output_tokens)
        
        with self._get_db_session() as db:
            # 检查并重置配额
            self._ensure_quota_reset(db, user_id)
            
            # 记录使用日志
            log = TokenUsageLog(
                user_id=user_id,
                session_id=session_id,
                model_name=model_name or "default",
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                total_tokens=total_tokens,
                api_cost=api_cost,
                endpoint=endpoint,
                request_id=request_id,
            )
            db.add(log)
            
            # 更新配额
            quota = db.query(UserTokenQuota).filter_by(user_id=user_id).first()
            if quota:
                quota.used_today += total_tokens
                quota.used_this_month += total_tokens
                quota.total_tokens_all_time += total_tokens
                quota.total_cost_all_time += api_cost
                
                # 扣除bonus
                if quota.bonus_tokens > quota.bonus_used:
                    bonus_used = min(total_tokens, quota.bonus_tokens - quota.bonus_used)
                    quota.bonus_used += bonus_used
            
            db.commit()
            
            return TokenUsage(
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                total_tokens=total_tokens,
                api_cost=api_cost,
                model_name=model_name or "default",
                endpoint=endpoint,
            )
    
    def _ensure_quota_reset(self, db, user_id: int):
        """确保配额重置（每日/每月）"""
        from database import UserTokenQuota
        
        quota = db.query(UserTokenQuota).filter_by(user_id=user_id).first()
        if not quota:
            return
        
        today = date.today()
        
        # 检查是否需要重置
        if quota.last_reset_date < today:
            quota.used_today = 0
            quota.last_reset_date = today
            
            # 检查是否新月份
            if (quota.last_reset_date.month != today.month or 
                quota.last_reset_date.year != today.year):
                quota.used_this_month = 0
    
    # --------------------------------------------------------------------------
    # 档位管理
    # --------------------------------------------------------------------------
    
    def upgrade_tier(self, user_id: int, new_tier: str) -> bool:
        """
        升级用户档位
        
        Args:
            user_id: 用户ID
            new_tier: 目标档位
            
        Returns:
            是否成功
        """
        if new_tier not in TIER_CONFIG:
            return False
        
        from database import UserTokenQuota
        
        tier_config = TIER_CONFIG[new_tier]
        
        with self._get_db_session() as db:
            quota = db.query(UserTokenQuota).filter_by(user_id=user_id).first()
            
            if not quota:
                quota = UserTokenQuota(user_id=user_id)
                db.add(quota)
            
            quota.tier = new_tier
            quota.quota_daily = tier_config["daily_quota"]
            quota.quota_monthly = tier_config["monthly_quota"]
            quota.rate_limit_per_min = tier_config["rate_limit_per_min"]
            quota.rate_limit_per_hour = tier_config["rate_limit_per_hour"]
            quota.payg_enabled = 1 if tier_config["payg_enabled"] else 0
            
            db.commit()
        
        return True
    
    def add_bonus_tokens(self, user_id: int, tokens: int) -> bool:
        """
        添加bonus token
        
        Args:
            user_id: 用户ID
            tokens: token数量
        """
        from database import UserTokenQuota
        
        with self._get_db_session() as db:
            quota = db.query(UserTokenQuota).filter_by(user_id=user_id).first()
            
            if not quota:
                quota = UserTokenQuota(user_id=user_id)
                db.add(quota)
            
            quota.bonus_tokens += tokens
            db.commit()
        
        return True
    
    # --------------------------------------------------------------------------
    # 统计
    # --------------------------------------------------------------------------
    
    def get_usage_summary(
        self,
        user_id: int,
        days: int = 30
    ) -> dict:
        """
        获取用户使用统计
        
        Args:
            user_id: 用户ID
            days: 统计天数
            
        Returns:
            统计信息
        """
        from database import TokenUsageLog, func
        from datetime import timedelta
        
        start_date = datetime.now() - timedelta(days=days)
        
        with self._get_db_session() as db:
            # 按端点聚合
            results = db.query(
                TokenUsageLog.endpoint,
                func.sum(TokenUsageLog.total_tokens).label("total_tokens"),
                func.sum(TokenUsageLog.input_tokens).label("input_tokens"),
                func.sum(TokenUsageLog.output_tokens).label("output_tokens"),
                func.sum(TokenUsageLog.api_cost).label("total_cost"),
                func.count(TokenUsageLog.id).label("request_count"),
            ).filter(
                TokenUsageLog.user_id == user_id,
                TokenUsageLog.created_at >= start_date,
            ).group_by(TokenUsageLog.endpoint).all()
            
            by_endpoint = {}
            total_tokens = 0
            total_cost = 0
            total_requests = 0
            
            for row in results:
                endpoint_data = {
                    "total_tokens": row.total_tokens or 0,
                    "input_tokens": row.input_tokens or 0,
                    "output_tokens": row.output_tokens or 0,
                    "total_cost": (row.total_cost or 0) / 1_000_000,
                    "request_count": row.request_count or 0,
                }
                by_endpoint[row.endpoint] = endpoint_data
                total_tokens += endpoint_data["total_tokens"]
                total_cost += endpoint_data["total_cost"]
                total_requests += endpoint_data["request_count"]
            
            return {
                "period_days": days,
                "total_tokens": total_tokens,
                "total_cost": total_cost,
                "total_requests": total_requests,
                "by_endpoint": by_endpoint,
            }
    
    def get_today_usage(self, user_id: int) -> dict:
        """获取今日使用统计"""
        return self.get_usage_summary(user_id, days=1)
    
    def get_usage_history(
        self,
        user_id: int,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
    ) -> dict:
        """
        获取用户使用历史（按日聚合，用于日历热力图）
        
        Args:
            user_id: 用户ID
            start_date: 开始日期 (YYYY-MM-DD)，默认90天前
            end_date: 结束日期 (YYYY-MM-DD)，默认今天
            
        Returns:
            按日期聚合的使用数据
        """
        from database import TokenUsageLog, func
        from datetime import datetime as dt, timedelta
        
        # 解析日期
        if end_date:
            end_dt = dt.strptime(end_date, "%Y-%m-%d").replace(
                hour=23, minute=59, second=59
            )
        else:
            end_dt = dt.now()
        
        if start_date:
            start_dt = dt.strptime(start_date, "%Y-%m-%d").replace(
                hour=0, minute=0, second=0
            )
        else:
            start_dt = end_dt - timedelta(days=89)  # 默认90天
        
        with self._get_db_session() as db:
            # 按日期分组聚合
            results = db.query(
                func.date(TokenUsageLog.created_at).label("usage_date"),
                func.sum(TokenUsageLog.total_tokens).label("total_tokens"),
                func.sum(TokenUsageLog.input_tokens).label("input_tokens"),
                func.sum(TokenUsageLog.output_tokens).label("output_tokens"),
                func.count(TokenUsageLog.id).label("request_count"),
            ).filter(
                TokenUsageLog.user_id == user_id,
                TokenUsageLog.created_at >= start_dt,
                TokenUsageLog.created_at <= end_dt,
            ).group_by(
                func.date(TokenUsageLog.created_at)
            ).order_by(
                func.date(TokenUsageLog.created_at)
            ).all()
            
            # 转换为响应格式
            data = []
            total_tokens = 0
            total_requests = 0
            
            for row in results:
                date_str = row.usage_date.strftime("%Y-%m-%d") if hasattr(row.usage_date, 'strftime') else str(row.usage_date)
                day_tokens = row.total_tokens or 0
                day_requests = row.request_count or 0
                
                data.append({
                    "date": date_str,
                    "total_tokens": day_tokens,
                    "request_count": day_requests,
                    "input_tokens": row.input_tokens or 0,
                    "output_tokens": row.output_tokens or 0,
                })
                total_tokens += day_tokens
                total_requests += day_requests
            
            return {
                "data": data,
                "total_tokens": total_tokens,
                "total_requests": total_requests,
                "start_date": start_dt.strftime("%Y-%m-%d"),
                "end_date": end_dt.strftime("%Y-%m-%d"),
            }
    
    # --------------------------------------------------------------------------
    # 辅助方法
    # --------------------------------------------------------------------------
    
    def _get_db_session(self):
        """获取数据库会话"""
        from database import get_session
        return get_session()


# ============================================================================
# 全局单例
# ============================================================================

_token_service: Optional[TokenService] = None


def get_token_service() -> TokenService:
    """获取Token服务单例"""
    global _token_service
    if _token_service is None:
        _token_service = TokenService()
    return _token_service


# ============================================================================
# 便捷函数
# ============================================================================

def record_usage(
    user_id: int,
    input_tokens: int = 0,
    output_tokens: int = 0,
    endpoint: str = "chat",
    model_name: str = "",
    session_id: Optional[int] = None,
) -> TokenUsage:
    """记录Token使用"""
    return get_token_service().record_usage(
        user_id=user_id,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        endpoint=endpoint,
        model_name=model_name,
        session_id=session_id,
    )


def get_quota(user_id: int) -> UserQuota:
    """获取用户配额"""
    return get_token_service().get_quota(user_id)


def check_quota(user_id: int, tokens: int) -> Tuple[bool, str]:
    """检查配额"""
    return get_token_service().check_quota(user_id, tokens)


def check_rate_limit(user_id: int) -> Tuple[bool, int]:
    """检查限流"""
    return get_token_service().check_rate_limit(user_id)


def upgrade_tier(user_id: int, new_tier: str) -> bool:
    """升级档位"""
    return get_token_service().upgrade_tier(user_id, new_tier)


def get_usage_history(
    user_id: int,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
) -> dict:
    """获取用户使用历史"""
    return get_token_service().get_usage_history(user_id, start_date, end_date)
