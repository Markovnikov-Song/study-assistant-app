"""
DispatchPipeline — 从用户输入到 ActionResult 的完整处理链路。

流程：
  用户输入
    → IntentMapper（LLM + 规则降级）
    → 参数完整性校验
    → [缺参] 返回 param_fill ActionResult
    → [完整] ExecutorRegistry.run()
    → ActionResult

顶层 try/except 保证任何情况下都返回合法 ActionResult，不向外传播异常。
"""
from __future__ import annotations

import logging
import time
from collections import deque
from typing import Any

from .action_registry import get_action_registry
from .executor_registry import ExecutorRegistry
from .intent_mapper import IntentMapper
from .models import ActionDef, ActionResult, ParamDef, RenderType

logger = logging.getLogger(__name__)

# ── 执行日志（循环缓冲区，最多 1000 条）──────────────────────────────────────

_dispatch_logs: deque[dict] = deque(maxlen=1000)


def get_dispatch_logs() -> list[dict]:
    """返回最近的 Dispatch 执行日志（调试用）。"""
    return list(_dispatch_logs)


class DispatchPipeline:
    """
    CAS 分发管道。
    单例使用，线程安全（无共享可变状态）。
    """

    _intent_mapper = IntentMapper()

    async def run(
        self,
        text: str,
        session_id: str | None,
        user_id: int,
    ) -> ActionResult:
        """
        完整处理链路入口。
        顶层 try/except 保证永远返回合法 ActionResult。
        """
        start = time.monotonic()
        action_id = "system_error"
        success = False
        fallback_used = False
        error_code = None

        try:
            result = await self._run_inner(text, session_id, user_id)
            action_id = result.action_id
            success = result.success
            fallback_used = result.fallback_used
            error_code = result.error_code
            return result

        except Exception as exc:
            logger.exception("DispatchPipeline: 未捕获异常：%s", exc)
            fallback_used = True
            error_code = "system_error"
            return ActionResult.system_error()

        finally:
            duration_ms = (time.monotonic() - start) * 1000
            _dispatch_logs.append({
                "action_id": action_id,
                "success": success,
                "duration_ms": round(duration_ms, 1),
                "fallback_used": fallback_used,
                "error_code": error_code,
                "session_id": session_id,
                "user_id": user_id,
            })

    async def _run_inner(
        self,
        text: str,
        session_id: str | None,
        user_id: int,
    ) -> ActionResult:
        """内部处理逻辑（不含顶层异常捕获）。"""
        registry = get_action_registry()

        # 1. 意图映射
        intent = await self._intent_mapper.map(text, session_id=session_id)
        action = registry.get_action(intent.action_id)

        # 兜底：action_id 不存在时使用 unknown_intent
        if action is None:
            action = registry.get_action("unknown_intent")
            if action is None:
                return ActionResult.system_error()

        # 2. 参数完整性校验
        is_complete, missing = self._validate_params(action, intent.params)

        if not is_complete:
            return ActionResult.param_fill(
                action_id=action.action_id,
                missing_params=missing,
                collected_params=intent.params,
            )

        # 3. 执行 Executor
        return await ExecutorRegistry.run(
            action_id=action.action_id,
            params=intent.params,
            user_id=user_id,
            fallback_text=action.fallback_text,
        )

    @staticmethod
    def _validate_params(
        action: ActionDef,
        params: dict[str, Any],
    ) -> tuple[bool, list[ParamDef]]:
        """
        校验参数完整性。
        返回 (is_complete, missing_required_params)。
        额外参数不影响完整性判断（属性 11）。
        """
        missing: list[ParamDef] = []
        for param_def in action.param_schema:
            if param_def.required and param_def.name not in params:
                missing.append(param_def)
        return len(missing) == 0, missing


# ── 模块级单例 ────────────────────────────────────────────────────────────────

_pipeline: DispatchPipeline | None = None


def get_pipeline() -> DispatchPipeline:
    global _pipeline
    if _pipeline is None:
        _pipeline = DispatchPipeline()
    return _pipeline
