from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType


@register_executor("open_course_space")
async def open_course_space_executor(params: dict, user_id: int) -> ActionResult:
    """跳转到课程空间（图书馆）页面。"""
    return ActionResult.ok(
        action_id="open_course_space",
        render_type=RenderType.navigate,
        route="/course-space",
    )
