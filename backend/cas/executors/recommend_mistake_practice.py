from cas.executor_registry import register_executor
from cas.models import ActionResult, RenderType

_FALLBACK = "暂时无法获取错题数据，请稍后再试"


@register_executor("recommend_mistake_practice")
async def recommend_mistake_practice_executor(params: dict, user_id: int) -> ActionResult:
    """查询错题库并推荐针对性练习，返回卡片。"""
    try:
        import sqlalchemy as sa
        from database import get_session

        subject = params.get("subject", "")

        with get_session() as db:
            rows = db.execute(
                sa.text(
                    "SELECT n.id, n.title, n.original_content, n.mistake_category, n.mastery_score "
                    "FROM notes n "
                    "JOIN notebooks nb ON nb.id = n.notebook_id "
                    "WHERE nb.user_id = :uid "
                    "  AND n.note_type = 'mistake' "
                    "  AND n.mistake_status = 'pending' "
                    "  AND (:subject = '' OR EXISTS ("
                    "    SELECT 1 FROM subjects s WHERE s.id = n.subject_id AND s.name = :subject"
                    "  )) "
                    "ORDER BY n.mastery_score ASC, n.created_at DESC "
                    "LIMIT 5"
                ),
                {"uid": user_id, "subject": subject},
            ).fetchall()

        if not rows:
            return ActionResult.ok(
                action_id="recommend_mistake_practice",
                render_type=RenderType.text,
                text=f"{'「' + subject + '」' if subject else ''}暂时没有待复盘的错题，继续加油！💪",
            )

        items = [
            {
                "id": row[0],
                "title": row[1] or (row[2][:30] + "…" if len(row[2]) > 30 else row[2]),
                "category": row[3] or "未分类",
                "mastery": row[4],
            }
            for row in rows
        ]

        return ActionResult.ok(
            action_id="recommend_mistake_practice",
            render_type=RenderType.card,
            card_type="mistake_list",
            title=f"为你推荐 {len(items)} 道待复盘错题",
            items=items,
            action_route="/toolkit/mistake-book",
        )

    except Exception as exc:
        import logging
        logging.getLogger(__name__).exception("recommend_mistake_practice 执行失败：%s", exc)
        return ActionResult.fallback("recommend_mistake_practice", _FALLBACK)
