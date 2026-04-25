from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType


@register_executor("unknown_intent")
async def unknown_intent_executor(params: dict, user_id: int) -> ActionResult:
    """兜底 Action：引导用户澄清意图。"""
    return ActionResult.ok(
        action_id="unknown_intent",
        render_type=RenderType.text,
        text="我没有完全理解你的意思 🤔\n\n你可以试试这样说：\n• 「帮我出几道高数题」\n• 「生成一份期末复习计划」\n• 「打开学习日历」\n• 「推荐一些错题练习」",
    )
