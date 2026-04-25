"""
ExecutorRegistry — @register_executor 装饰器 + 统一执行入口。

用法：
    from cas.executor_registry import register_executor, ExecutorRegistry

    @register_executor("make_quiz")
    async def make_quiz_executor(params: dict, user_id: int) -> ActionResult:
        ...

    result = await ExecutorRegistry.run("make_quiz", params, user_id=1)
"""
from __future__ import annotations

import logging
from typing import Any, Callable, Optional

from .models import ActionResult, RenderType

logger = logging.getLogger(__name__)

# ── 全局 Executor 注册表 ──────────────────────────────────────────────────────

_executor_registry: dict[str, Callable] = {}


def register_executor(action_id: str) -> Callable:
    """
    装饰器：将函数注册为指定 action_id 的 Executor。

    被装饰的函数签名必须为：
        async def executor(params: dict, user_id: int) -> ActionResult
    """
    def decorator(fn: Callable) -> Callable:
        _executor_registry[action_id] = fn
        logger.debug("ExecutorRegistry: 注册 Executor '%s' -> %s", action_id, fn.__name__)
        return fn
    return decorator


def get_executor(action_id: str) -> Optional[Callable]:
    """获取指定 action_id 的 Executor 函数，不存在返回 None。"""
    return _executor_registry.get(action_id)


def list_registered_executors() -> list[str]:
    """返回所有已注册的 action_id 列表（调试用）。"""
    return list(_executor_registry.keys())


class ExecutorRegistry:
    """
    Executor 统一执行入口。
    捕获 Executor 内部所有异常，保证永远返回合法的 ActionResult。
    """

    @staticmethod
    async def run(
        action_id: str,
        params: dict[str, Any],
        user_id: int,
        fallback_text: str = "操作暂时不可用，请稍后再试",
    ) -> ActionResult:
        """
        执行指定 action_id 的 Executor。

        - Executor 不存在时返回 fallback
        - Executor 内部抛出任意异常时捕获并返回 fallback
        - 永远不向调用方传播异常
        """
        executor = get_executor(action_id)

        if executor is None:
            logger.warning("ExecutorRegistry: action_id '%s' 无对应 Executor", action_id)
            return ActionResult.fallback(
                action_id=action_id,
                fallback_text=fallback_text,
                error_code="executor_not_found",
            )

        try:
            result = await executor(params, user_id)
            # 确保返回值是 ActionResult
            if not isinstance(result, ActionResult):
                logger.error(
                    "ExecutorRegistry: Executor '%s' 返回了非 ActionResult 类型：%s",
                    action_id, type(result),
                )
                return ActionResult.fallback(action_id=action_id, fallback_text=fallback_text)
            return result

        except Exception as exc:
            logger.exception(
                "ExecutorRegistry: Executor '%s' 执行异常：%s",
                action_id, exc,
            )
            return ActionResult.fallback(
                action_id=action_id,
                fallback_text=fallback_text,
                error_code="executor_error",
            )
