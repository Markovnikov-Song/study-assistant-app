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
from typing import Any, Union

from fastapi.responses import StreamingResponse

from .action_registry import get_action_registry
from .executor_registry import ExecutorRegistry, get_executor
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
        images: list[str] | None = None,
        supplement_text: str | None = None,
    ) -> Union[ActionResult, StreamingResponse]:
        """
        完整处理链路入口。
        顶层 try/except 保证永远返回合法 ActionResult 或 StreamingResponse。
        """
        start = time.monotonic()
        action_id = "system_error"
        success = False
        fallback_used = False
        error_code = None

        try:
            result = await self._run_inner(text, session_id, user_id, images=images, supplement_text=supplement_text)
            # StreamingResponse 直接透传，不记录 action_id
            if isinstance(result, StreamingResponse):
                return result
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
        images: list[str] | None = None,
        supplement_text: str | None = None,
    ) -> Union[ActionResult, StreamingResponse]:
        """内部处理逻辑（不含顶层异常捕获）。"""
        registry = get_action_registry()

        # 1. 意图映射（透传 images 给 IntentMapper，触发多模态短路规则）
        intent = await self._intent_mapper.map(
            text, session_id=session_id, images=images
        )
        intent.params.setdefault("original_text", text)
        resolved_action_id = intent.action_id
        action = registry.get_action(resolved_action_id)

        # YAML 漏配但 Executor 已注册：仍执行真实意图，避免误降级 unknown_intent
        if action is None and get_executor(resolved_action_id) is not None:
            logger.error(
                "DispatchPipeline: ActionRegistry 缺少 '%s'，但 Executor 已注册，继续执行",
                resolved_action_id,
            )
            fallback_text = "操作暂时不可用，请稍后再试"
        elif action is None:
            logger.warning(
                "DispatchPipeline: 意图 '%s' 无 Action 定义且无 Executor，降级 unknown_intent",
                resolved_action_id,
            )
            resolved_action_id = "unknown_intent"
            action = registry.get_action("unknown_intent")
            if action is None:
                return ActionResult.system_error()
            fallback_text = action.fallback_text
        else:
            fallback_text = action.fallback_text

        # 2. 将多模态参数注入 intent.params，供 executor 使用
        if images is not None:
            intent.params["images"] = images
        if supplement_text is not None:
            intent.params["supplement_text"] = supplement_text
        elif images:
            # 有图片但无补充文字时，填充空字符串，避免 executor 处理 None
            intent.params["supplement_text"] = ""

        # 3. 参数完整性校验
        is_complete, missing = self._validate_params(action, intent.params)

        if not is_complete:
            return ActionResult.param_fill(
                action_id=resolved_action_id,
                missing_params=missing,
                collected_params=intent.params,
            )

        # 4. 执行 Executor（可能返回 StreamingResponse）
        return await ExecutorRegistry.run(
            action_id=resolved_action_id,
            params=intent.params,
            user_id=user_id,
            fallback_text=fallback_text,
        )

    @staticmethod
    def _validate_params(
        action: ActionDef | None,
        params: dict[str, Any],
    ) -> tuple[bool, list[ParamDef]]:
        """
        校验参数完整性。
        返回 (is_complete, missing_required_params)。
        额外参数不影响完整性判断（属性 11）。
        """
        if action is None:
            return True, []
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
