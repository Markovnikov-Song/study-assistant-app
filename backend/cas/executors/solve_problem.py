from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType


@register_executor("solve_problem")
async def solve_problem_executor(params: dict, user_id: int) -> ActionResult:
    """跳转到解题页面。"""
    return ActionResult.ok(
        action_id="solve_problem",
        render_type=RenderType.navigate,
        route="/toolkit/solve",
    )
