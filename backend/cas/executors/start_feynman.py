from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType

_FALLBACK = "暂时无法开启费曼学习，请稍后再试"


@register_executor("start_feynman")
async def start_feynman_executor(params: dict, user_id: int) -> ActionResult:
    """
    开启费曼学习对话：
    - 返回 navigate 指令，跳转到聊天页（feynman session_type）
    - 前端收到后新建 feynman 会话，并自动注入引导消息
    """
    try:
        topic = params.get("topic", "").strip()
        subject_id = params.get("subject_id")

        if not topic:
            return ActionResult.fallback("start_feynman", "请告诉我你想练习哪个知识点", "missing_params")

        # 构建路由：跳转到聊天页，携带 feynman 模式参数
        import urllib.parse
        query_parts = [f"mode=feynman", f"topic={urllib.parse.quote(topic)}"]
        if subject_id:
            query_parts.append(f"subject_id={subject_id}")
        route = f"/chat/feynman?{'&'.join(query_parts)}"

        return ActionResult.ok(
            action_id="start_feynman",
            render_type=RenderType.navigate,
            route=route,
            # 额外数据供前端注入引导消息
            topic=topic,
            subject_id=subject_id,
        )
    except Exception as exc:
        import logging
        logging.getLogger(__name__).exception("start_feynman 执行失败：%s", exc)
        return ActionResult.fallback("start_feynman", _FALLBACK)
