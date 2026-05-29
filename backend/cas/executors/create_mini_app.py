from __future__ import annotations

from urllib.parse import urlencode

from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType


@register_executor("create_mini_app")
async def create_mini_app_executor(params: dict, user_id: int) -> ActionResult:
    request = str(
        params.get("initial_request")
        or params.get("request")
        or params.get("original_text")
        or ""
    ).strip()
    query = urlencode({"request": request}) if request else ""
    route = f"/workshop/builder?{query}" if query else "/workshop/builder"
    return ActionResult.ok(
        action_id="create_mini_app",
        render_type=RenderType.navigate,
        route=route,
    )
