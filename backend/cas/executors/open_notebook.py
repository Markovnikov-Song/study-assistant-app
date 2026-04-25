from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType


@register_executor("open_notebook")
async def open_notebook_executor(params: dict, user_id: int) -> ActionResult:
    """跳转到笔记本页面。"""
    return ActionResult.ok(
        action_id="open_notebook",
        render_type=RenderType.navigate,
        route="/toolkit/notebooks",
    )
