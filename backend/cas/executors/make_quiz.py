from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType

_FALLBACK = "出题服务暂时不可用，请稍后再试"


@register_executor("make_quiz")
async def make_quiz_executor(params: dict, user_id: int) -> ActionResult:
    """调用出题逻辑，返回跳转到出题页面的导航指令。"""
    try:
        subject = params.get("subject", "")
        question_types = params.get("question_type", ["选择题"])
        count = int(params.get("count", 5))

        # 构建跳转路由（携带参数）
        import urllib.parse
        query = urllib.parse.urlencode({
            "subject": subject,
            "types": ",".join(question_types) if isinstance(question_types, list) else question_types,
            "count": count,
        })

        return ActionResult.ok(
            action_id="make_quiz",
            render_type=RenderType.navigate,
            route=f"/toolkit/quiz?{query}",
        )

    except Exception as exc:
        import logging
        logging.getLogger(__name__).exception("make_quiz 执行失败：%s", exc)
        return ActionResult.fallback("make_quiz", _FALLBACK)
