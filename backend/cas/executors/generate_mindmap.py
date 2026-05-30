from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType


@register_executor("generate_mindmap")
async def generate_mindmap_executor(params: dict, user_id: int) -> ActionResult:
    """跳转到思维导图生成入口。"""
    return ActionResult.ok(
        action_id="generate_mindmap",
        render_type=RenderType.navigate,
        route="/mindmap-entry?generate=1",
    )
