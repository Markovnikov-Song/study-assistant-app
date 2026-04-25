"""
安全增强模块：管理员权限验证和速率限制
"""
from functools import wraps
from fastapi import Depends, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
import time

# 速率限制器
limiter = Limiter(key_func=get_remote_address)

# 简单的内存存储用于速率限制（生产环境应使用 Redis）
_rate_limit_store = {}


def is_admin(user_id: int) -> bool:
    """
    检查用户是否为管理员。

    当前实现：仅 user_id == 1 为管理员。
    生产环境应从数据库读取用户角色。

    Args:
        user_id: 用户ID

    Returns:
        是否为管理员
    """
    # TODO: 替换为数据库查询
    # 示例: db.query(User).filter_by(id=user_id, role="admin").first() is not None
    return user_id == 1


def require_admin(func):
    """
    管理员权限验证装饰器。

    用于保护管理员专属的 API 端点。
    """
    @wraps(func)
    async def wrapper(*args, **kwargs):
        # 查找 current_user 参数
        current_user = None
        for arg in args:
            if isinstance(arg, dict) and "id" in arg:
                current_user = arg
                break

        if current_user is None:
            # 尝试从 kwargs 获取
            current_user = kwargs.get("user") or kwargs.get("current_user")

        if not current_user or "id" not in current_user:
            raise HTTPException(401, "未认证")

        if not is_admin(current_user["id"]):
            raise HTTPException(403, "需要管理员权限")

        return await func(*args, **kwargs)
    return wrapper


def check_rate_limit(user_id: int, action: str, max_requests: int = 10, window_seconds: int = 60) -> bool:
    """
    检查用户操作速率限制。

    Args:
        user_id: 用户ID
        action: 操作类型
        max_requests: 时间窗口内最大请求数
        window_seconds: 时间窗口（秒）

    Returns:
        是否允许请求
    """
    key = f"{user_id}:{action}"
    now = time.time()

    if key not in _rate_limit_store:
        _rate_limit_store[key] = []

    # 清理过期记录
    _rate_limit_store[key] = [
        t for t in _rate_limit_store[key]
        if now - t < window_seconds
    ]

    if len(_rate_limit_store[key]) >= max_requests:
        return False

    _rate_limit_store[key].append(now)
    return True


def admin_rate_limit(max_requests: int = 30, window_seconds: int = 60):
    """
    管理员操作速率限制装饰器。

    Args:
        max_requests: 时间窗口内最大请求数
        window_seconds: 时间窗口（秒）
    """
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            current_user = None
            for arg in args:
                if isinstance(arg, dict) and "id" in arg:
                    current_user = arg
                    break

            if current_user is None:
                current_user = kwargs.get("user") or kwargs.get("current_user")

            if not current_user:
                raise HTTPException(401, "未认证")

            action = func.__name__
            if not check_rate_limit(current_user["id"], action, max_requests, window_seconds):
                raise HTTPException(
                    429,
                    f"操作过于频繁，请在 {window_seconds} 秒后重试"
                )

            return await func(*args, **kwargs)
        return wrapper
    return decorator
