from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType

_FALLBACK = "概念解释服务暂时不可用，请稍后再试"


@register_executor("explain_concept")
async def explain_concept_executor(params: dict, user_id: int) -> ActionResult:
    """调用 LLM 解释概念，返回文本消息。"""
    try:
        from services.llm_service import LLMService
        from backend_config import get_config

        concept = params.get("concept", "").strip()
        if not concept:
            return ActionResult.fallback("explain_concept", "请告诉我你想了解的概念", "missing_params")

        llm = LLMService()
        content = llm.chat(
            [
                {"role": "system", "content": "你是一位善于用通俗语言解释概念的老师，解释要简洁清晰，配合例子，不超过 300 字。"},
                {"role": "user", "content": f"请解释：{concept}"},
            ],
            max_tokens=get_config().LLM_EXECUTE_NODE_MAX_TOKENS,
        )

        return ActionResult.ok(
            action_id="explain_concept",
            render_type=RenderType.text,
            text=content,
        )

    except Exception as exc:
        import logging
        logging.getLogger(__name__).exception("explain_concept 执行失败：%s", exc)
        return ActionResult.fallback("explain_concept", _FALLBACK)
