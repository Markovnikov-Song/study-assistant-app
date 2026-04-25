from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType


@register_executor("open_calendar")
async def open_calendar_executor(params: dict, user_id: int) -> ActionResult:
    """跳转到学习日历页面。"""
    return ActionResult.ok(
        action_id="open_calendar",
        render_type=RenderType.navigate,
        route="/toolkit/calendar",
    )
