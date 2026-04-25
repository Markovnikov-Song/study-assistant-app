"""
study_planner_service.py — Study Planner Multi-Agent 规划服务

职责：
  1. generate_plan()  — 并行 SubjectAgent + AcademicAgent 排期，写入 plan_items
  2. sync_node_completion() — 节点点亮时静默同步 plan_item 状态
  3. check_plan_completion() — 检查计划是否全部完成

数据源（_run_subject_agent）：
  思维导图是规划的必要数据源（详细的层级知识点）。
  如果学科没有 mindmap session，自动调用 MindMapService 生成一个并存储。
"""
from __future__ import annotations

import json
import logging
import re
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError as FuturesTimeout
from datetime import date, datetime, timedelta, timezone
from typing import Any, Optional

logger = logging.getLogger(__name__)


# ── 节点文本从 Markdown 内容中提取 ────────────────────────────────────────────

def _extract_nodes_from_markdown(content: str) -> list[dict]:
    """
    从 Markdown 大纲文本中提取节点列表（含 node_id、text、depth、parent_id）。
    复用 library.py 的 _build_node_tree 逻辑。
    """
    nodes = []
    stack: list[dict] = []  # (depth, node_id)

    for line in content.splitlines():
        # 标题行：# text
        m = re.match(r'^(#{1,6})\s+(.+)', line.strip())
        if m:
            depth = len(m.group(1))
            text = m.group(2).strip()
            node_id = f"node_{len(nodes)}_{re.sub(r'[^a-zA-Z0-9]', '_', text[:20])}"

            # 找父节点
            while stack and stack[-1]['depth'] >= depth:
                stack.pop()
            parent_id = stack[-1]['node_id'] if stack else None

            node = {
                'node_id': node_id,
                'text': text,
                'depth': depth,
                'parent_id': parent_id,
            }
            nodes.append(node)
            stack.append({'depth': depth, 'node_id': node_id})
            continue

        # 列表行：- text 或 * text
        m2 = re.match(r'^[-*]\s+(.+)', line.strip())
        if m2:
            text = m2.group(1).strip()
            node_id = f"node_{len(nodes)}_{re.sub(r'[^a-zA-Z0-9]', '_', text[:20])}"
            parent_id = stack[-1]['node_id'] if stack else None
            depth = (stack[-1]['depth'] + 1) if stack else 1
            node = {
                'node_id': node_id,
                'text': text,
                'depth': depth,
                'parent_id': parent_id,
            }
            nodes.append(node)

    return nodes


# ── SubjectAgent ──────────────────────────────────────────────────────────────

def _run_subject_agent(
    subject_id: int,
    user_id: int,
    db,
) -> dict:
    """
    单学科节点分析：
    1. 查询该学科的 mindmap sessions（从 ConversationHistory 读取 Markdown 内容）
    2. 如果没有 mindmap session，自动调用 MindMapService 生成一个
    3. 从 Markdown 内容提取节点树
    4. 与 mindmap_node_states 对比，筛选 unlit 节点
    5. 用 LLM 标注优先级和预估时长

    返回：{subject_id, subject_name, has_mindmap, source, nodes: [...]}
    """
    from database import Chunk, ConversationHistory, ConversationSession, MindmapNodeState, Subject

    # 获取学科名称
    subject = db.query(Subject).filter_by(id=subject_id).first()
    subject_name = subject.name if subject else f"学科{subject_id}"

    # 查找该学科已有的 mindmap sessions
    mindmap_sessions = (
        db.query(ConversationSession)
        .filter_by(subject_id=subject_id, session_type="mindmap")
        .order_by(ConversationSession.is_pinned.desc(), ConversationSession.created_at.desc())
        .limit(3)
        .all()
    )

    # 从 ConversationHistory 读取 mindmap Markdown 内容
    mindmap_content = None
    session_id = None
    for sess in mindmap_sessions:
        # 取该 session 最新一条 assistant 消息（即 mindmap 生成结果）
        latest_msg = (
            db.query(ConversationHistory.content)
            .filter_by(session_id=sess.id, role="assistant")
            .order_by(ConversationHistory.created_at.desc())
            .first()
        )
        if latest_msg and latest_msg[0]:
            mindmap_content = latest_msg[0]
            session_id = sess.id
            break

    # 如果没有 mindmap → 自动生成一个
    auto_generated = False
    if not mindmap_content:
        logger.info("SubjectAgent[%s]: 无 mindmap，自动生成", subject_name)
        mindmap_content = _auto_generate_mindmap(subject_id, subject_name, user_id, db)
        if mindmap_content:
            auto_generated = True
            # 获取刚创建的 session_id
            new_session = (
                db.query(ConversationSession)
                .filter_by(subject_id=subject_id, session_type="mindmap")
                .order_by(ConversationSession.created_at.desc())
                .first()
            )
            session_id = new_session.id if new_session else None

    if not mindmap_content:
        logger.warning("SubjectAgent[%s]: 无法获取/生成 mindmap（可能学科下无文档）", subject_name)
        return {
            'subject_id': subject_id,
            'subject_name': subject_name,
            'has_mindmap': False,
            'source': 'none',
            'nodes': [],
        }

    # 从 Markdown 提取节点树
    all_nodes = _extract_nodes_from_markdown(mindmap_content)
    if not all_nodes:
        logger.warning("SubjectAgent[%s]: mindmap 内容未解析到节点", subject_name)
        return {
            'subject_id': subject_id,
            'subject_name': subject_name,
            'has_mindmap': False,
            'source': 'empty_mindmap',
            'nodes': [],
        }

    # 查询已点亮节点
    lit_node_ids: set[str] = set()
    if session_id:
        lit_rows = (
            db.query(MindmapNodeState)
            .filter_by(user_id=user_id, session_id=session_id, is_lit=1)
            .all()
        )
        lit_node_ids = {r.node_id for r in lit_rows}

    # 筛选 unlit 节点
    unlit_nodes = [n for n in all_nodes if n['node_id'] not in lit_node_ids]

    if not unlit_nodes:
        # 全部节点已点亮 → 无需规划
        return {
            'subject_id': subject_id,
            'subject_name': subject_name,
            'has_mindmap': True,
            'source': 'auto_generated' if auto_generated else 'all_lit',
            'nodes': [],
        }

    # 用 LLM 标注优先级和预估时长（批量，最多 20 个节点）
    annotated = _annotate_nodes_with_llm(unlit_nodes[:20], subject_name, user_id, db)

    return {
        'subject_id': subject_id,
        'subject_name': subject_name,
        'has_mindmap': True,
        'source': 'auto_generated' if auto_generated else 'mindmap',
        'nodes': annotated,
    }


def _auto_generate_mindmap(
    subject_id: int,
    subject_name: str,
    user_id: int,
    db,
) -> Optional[str]:
    """
    自动为学科生成 mindmap 并存入 ConversationSession + ConversationHistory。
    返回生成的 Markdown 内容，失败返回 None。
    """
    from database import Chunk, ConversationHistory, ConversationSession, Document

    # 检查学科下是否有已完成解析的文档
    completed_doc_ids = [
        row[0] for row in
        db.query(Document.id)
        .filter_by(subject_id=subject_id, status='completed')
        .all()
    ]

    if not completed_doc_ids:
        logger.warning("_auto_generate_mindmap[%s]: 学科下无已完成解析的文档", subject_name)
        return None

    # 获取 chunks
    chunk_rows = (
        db.query(Chunk.content)
        .filter(Chunk.document_id.in_(completed_doc_ids))
        .order_by(Chunk.chunk_index)
        .all()
    )

    if not chunk_rows:
        return None

    chunks = [row[0] for row in chunk_rows]

    # 调用 MindMapService 生成
    try:
        from services.mindmap_service import MindMapService

        svc = MindMapService(user_id=user_id)
        content = svc.generate(chunks, subject_name)

        if not content or len(content.strip()) < 20:
            logger.warning("_auto_generate_mindmap[%s]: 生成内容过短", subject_name)
            return None

        # 创建 ConversationSession（mindmap 类型）
        session_obj = ConversationSession(
            user_id=user_id,
            subject_id=subject_id,
            session_type="mindmap",
            title=f"{subject_name} 知识导图（自动生成）",
        )
        db.add(session_obj)
        db.flush()
        new_session_id = session_obj.id

        # 存入 ConversationHistory
        db.add(ConversationHistory(
            session_id=new_session_id,
            role="user",
            content="自动生成思维导图（学习规划触发）",
        ))
        db.add(ConversationHistory(
            session_id=new_session_id,
            role="assistant",
            content=content,
        ))

        logger.info("_auto_generate_mindmap[%s]: 自动生成成功，session_id=%s", subject_name, new_session_id)
        return content

    except Exception as e:
        logger.warning("_auto_generate_mindmap[%s] 失败：%s", subject_name, e)
        return None


def _annotate_nodes_with_llm(
    nodes: list[dict],
    subject_name: str,
    user_id: int,
    db,
) -> list[dict]:
    """
    调用 LLM 为节点标注优先级（high/medium/low）和预估学习时长（15-45 分钟）。
    失败时使用默认值。
    """
    try:
        from services.llm_service import LLMService
        from backend_config import get_config

        cfg = get_config()
        llm = LLMService()

        node_list_text = '\n'.join(
            f"{i+1}. {n['text']} (深度{n['depth']})"
            for i, n in enumerate(nodes)
        )

        prompt = f"""你是一位{subject_name}学科的教学专家。
以下是学生尚未掌握的知识点列表，请为每个知识点标注：
1. 优先级：high（重点/难点）、medium（一般）、low（补充内容）
2. 预估学习时长（分钟）：15、20、25、30、45 中选一个

知识点列表：
{node_list_text}

请以 JSON 数组格式返回，每项包含 index（从1开始）、priority、minutes：
[{{"index": 1, "priority": "high", "minutes": 30}}, ...]
只返回 JSON，不要其他内容。"""

        model = getattr(llm, 'get_model_for_scene', lambda _: None)("fast")
        kwargs = {}
        if model:
            kwargs['model'] = model
        raw = llm.chat([{"role": "user", "content": prompt}], max_tokens=512, **kwargs)

        # 解析 JSON
        raw = raw.strip()
        if raw.startswith('```'):
            raw = re.sub(r'^```[a-z]*\n?', '', raw)
            raw = re.sub(r'\n?```$', '', raw)
        annotations = json.loads(raw)

        ann_map = {item['index']: item for item in annotations}
        for i, node in enumerate(nodes):
            ann = ann_map.get(i + 1, {})
            node['priority'] = ann.get('priority', 'medium')
            node['estimated_minutes'] = int(ann.get('minutes', 20))

    except Exception as e:
        logger.warning("LLM 节点标注失败，使用默认值：%s", e)
        for node in nodes:
            node.setdefault('priority', 'medium')
            node.setdefault('estimated_minutes', 20)

    # 从 MemoryService 提升 weak_points 节点优先级
    try:
        _boost_weak_points(nodes, user_id, db)
    except Exception:
        pass

    return nodes


def _boost_weak_points(nodes: list[dict], user_id: int, db) -> None:
    """将 MemoryService weak_points 中出现的节点优先级提升为 high。"""
    from database import UserMemory

    memory = db.query(UserMemory).filter_by(user_id=user_id).first()
    if not memory or not memory.memory_data:
        return

    weak_points = memory.memory_data.get('weak_points', [])
    if not weak_points:
        return

    weak_texts = {str(w).lower() for w in weak_points}
    for node in nodes:
        if any(w in node['text'].lower() for w in weak_texts):
            node['priority'] = 'high'


# ── 查询已有日历事件（排课前感知路况）─────────────────────────────────

def _get_existing_calendar_events(
    user_id: int,
    start_date: date,
    deadline_date: date,
    db,
) -> dict[date, list[dict]]:
    """
    查询用户在 [start_date, deadline_date] 范围内已有的日历事件。
    返回 {date: [{title, start_time, duration_minutes, source, plan_id}]} 字典。
    """
    from sqlalchemy import text

    rows = db.execute(text("""
        SELECT event_date, title, start_time, duration_minutes, source, plan_id
        FROM calendar_events
        WHERE user_id = :uid
          AND event_date BETWEEN :start AND :end
        ORDER BY event_date, start_time
    """), {"uid": user_id, "start": start_date, "end": deadline_date}).fetchall()

    by_date: dict[date, list[dict]] = {}
    for row in rows:
        d = row.event_date if hasattr(row.event_date, 'isoformat') else date.fromisoformat(str(row.event_date))
        by_date.setdefault(d, []).append({
            "title": row.title,
            "start_time": str(row.start_time)[:5],
            "duration_minutes": row.duration_minutes,
            "source": row.source,
            "plan_id": row.plan_id,
        })
    return by_date


# ── AcademicAgent 排期 ────────────────────────────────────────────────────────

def _schedule_items(
    subject_analyses: list[dict],
    deadline: datetime,
    daily_minutes: int,
    start_date: date,
    existing_events: Optional[dict[date, list[dict]]] = None,
) -> list[dict]:
    """
    贪心排期算法：
    1. 拓扑排序（依赖关系）
    2. 按优先级排序（high > medium > low）
    3. 按日期从 start_date 到 deadline 贪心分配
    4. 单科 ≤ 60% 每日时长
    5. 时间不足时优先排 high 优先级节点
    6. 跳过已被已有日历事件占用的时段
    """
    existing = existing_events or {}

    # 收集所有节点，附加 subject 信息
    all_nodes = []
    for analysis in subject_analyses:
        for node in analysis.get('nodes', []):
            all_nodes.append({
                **node,
                'subject_id': analysis['subject_id'],
                'subject_name': analysis['subject_name'],
            })

    if not all_nodes:
        return []

    # 按优先级排序
    priority_order = {'high': 0, 'medium': 1, 'low': 2}
    all_nodes.sort(key=lambda n: priority_order.get(n.get('priority', 'medium'), 1))

    # 计算可用天数
    deadline_date = deadline.date() if hasattr(deadline, 'date') else deadline
    total_days = (deadline_date - start_date).days
    if total_days <= 0:
        total_days = 1

    # 计算每天已被占用的时间（从已有日历事件）
    def _get_existing_minutes(d: date) -> int:
        evts = existing.get(d, [])
        return sum(e["duration_minutes"] for e in evts if e["source"] != "study-planner")

    # 贪心分配
    scheduled = []
    day_usage: dict[date, int] = {}          # date → 已用分钟
    day_subject_usage: dict[tuple, int] = {} # (date, subject_id) → 已用分钟
    max_per_subject = int(daily_minutes * 0.6)

    for node in all_nodes:
        minutes = node.get('estimated_minutes', 20)
        subject_id = node['subject_id']
        placed = False

        for day_offset in range(total_days):
            d = start_date + timedelta(days=day_offset)
            used = day_usage.get(d, _get_existing_minutes(d))
            subj_used = day_subject_usage.get((d, subject_id), 0)

            if used + minutes <= daily_minutes and subj_used + minutes <= max_per_subject:
                day_usage[d] = used + minutes
                day_subject_usage[(d, subject_id)] = subj_used + minutes
                scheduled.append({
                    **node,
                    'planned_date': d,
                })
                placed = True
                break

        if not placed:
            # 时间不足：只排 high 优先级节点到最后一天
            if node.get('priority') == 'high':
                d = deadline_date - timedelta(days=1)
                scheduled.append({**node, 'planned_date': d})

    return scheduled


# ── Council Advisor 智能调度建议 ─────────────────────────────────────────────

def _advisor_schedule_suggestion(
    subject_analyses: list[dict],
    deadline: datetime,
    daily_minutes: int,
    start_date: date,
    existing_events: Optional[dict[date, list[dict]]] = None,
) -> Optional[list[dict]]:
    """
    尝试调用 Council advisor 的 LLM 能力获取智能排课建议。
    排课前感知已有日历事件（"路况"），避免时间冲突。
    返回建议的排期列表，或 None（失败时降级到贪心）。
    """
    try:
        from services.llm_service import LLMService
        from backend_config import get_config

        llm = LLMService()
        cfg = get_config()
        existing = existing_events or {}

        # 构建学科进度摘要
        subject_info = []
        for analysis in subject_analyses:
            nodes = analysis.get("nodes", [])
            if not nodes:
                continue
            subject_info.append({
                "name": analysis.get("subject_name", "未知"),
                "subject_id": analysis.get("subject_id"),
                "nodes": [
                    {
                        "text": n["text"][:60],
                        "priority": n.get("priority", "medium"),
                        "minutes": n.get("estimated_minutes", 20),
                    }
                    for n in nodes[:10]
                ],
                "total_nodes": len(nodes),
            })

        if not subject_info:
            return None

        deadline_str = deadline.date().isoformat() if hasattr(deadline, "date") else str(deadline)
        total_days = max(1, (date.fromisoformat(deadline_str) - start_date).days)

        # 构建已有日历事件摘要（"路况信息"）
        calendar_summary_lines = []
        for d in sorted(existing.keys()):
            evts = existing[d]
            # 只关注非 study-planner 来源的事件（避免自己和自己冲突）
            user_events = [e for e in evts if e["source"] != "study-planner"]
            if not user_events:
                continue
            total_mins = sum(e["duration_minutes"] for e in user_events)
            items = ", ".join(
                f"{e['start_time']}({e['duration_minutes']}min:{e['title']})" for e in user_events
            )
            calendar_summary_lines.append(f"  {d.isoformat()}: 已安排 {total_mins} 分钟 — {items}")

        calendar_context = ""
        if calendar_summary_lines:
            calendar_context = f"""
⚠️ 重要：该学生在以下日期已有安排，新排课必须避开这些时段（或者安排在这些时段之外）！
已有日程：
{chr(10).join(calendar_summary_lines)}

"""
        prompt = f"""你是班主任，需要将以下学科的学习任务分配到 {total_days} 天内（{start_date.isoformat()} 到 {deadline_str}），每天 {daily_minutes} 分钟。
{calendar_context}
学科与任务：
{json.dumps(subject_info, ensure_ascii=False, indent=2)}

排课规则：
1. 同一天单科不超过总时长的 60%
2. 优先排高优先级（high）任务
3. 同学科任务尽量不连续出现
4. 最后 3 天留作综合复习
5. {"已有日程的日期，新任务必须安排在已有日程之外的空闲时段！" if calendar_summary_lines else "目前日程为空，自由安排。"}

请以 JSON 数组格式返回排期结果，每项包含：
- subject_id: 学科ID
- node_text: 任务描述（从输入原样复制）
- priority: 优先级
- estimated_minutes: 预估分钟数
- node_id: 用 "s{{subject_id}}_{{index}}" 格式
- planned_date: YYYY-MM-DD

只返回 JSON 数组，不要其他内容。"""

        model = getattr(llm, "get_model_for_scene", lambda _: None)("fast")
        kwargs = {}
        if model:
            kwargs["model"] = model
        raw = llm.chat(
            [{"role": "user", "content": prompt}],
            max_tokens=2048,
            temperature=0.3,
            **kwargs,
        )

        # 解析 JSON
        raw = raw.strip()
        if raw.startswith("```"):
            raw = re.sub(r"^```[a-z]*\n?", "", raw)
            raw = re.sub(r"\n?```$", "", raw)
        suggestions = json.loads(raw)

        if not isinstance(suggestions, list) or not suggestions:
            return None

        # 验证并标准化
        valid = []
        for item in suggestions:
            planned_date_str = item.get("planned_date", "")
            try:
                pd = date.fromisoformat(planned_date_str)
            except (ValueError, TypeError):
                continue
            if pd < start_date or pd > date.fromisoformat(deadline_str):
                continue
            valid.append({
                "subject_id": item.get("subject_id"),
                "subject_name": "",  # 后面补
                "node_id": item.get("node_id", f"s{item.get('subject_id', 0)}_0"),
                "text": item.get("node_text", "")[:256],
                "priority": item.get("priority", "medium"),
                "estimated_minutes": max(15, min(480, int(item.get("estimated_minutes", 20)))),
                "planned_date": pd,
                "parent_id": None,
            })

        if valid:
            logger.info("Council Advisor 排课建议：%d 条有效任务", len(valid))
            return valid

    except Exception as e:
        logger.warning("Council Advisor 智能排课失败，降级到贪心：%s", e)
    return None


# ── 写入日历事件 ─────────────────────────────────────────────────────────────

def _sync_plan_to_calendar(
    user_id: int,
    plan_id: int,
    scheduled: list[dict],
    db,
) -> int:
    """
    将排好的 plan items 批量写入 calendar_events 表。
    - 先清理同 plan_id 的旧事件（幂等：重复生成计划不会产生重复）
    - 查询每天已有事件，计算实际可用时间段
    - 使用 plan_id 字段做结构化关联
    返回写入的事件数量。
    """
    from sqlalchemy import text

    if not scheduled:
        return 0

    # 清理旧的同 plan_id 事件（幂等）
    db.execute(text("""
        DELETE FROM calendar_events
        WHERE user_id = :uid AND plan_id = :plan_id
    """), {"uid": user_id, "plan_id": plan_id})

    # 查询排课范围内已有事件（用于避开已有时间段）
    dates = sorted({item["planned_date"] for item in scheduled})
    if not dates:
        return 0
    start_d = min(dates)
    end_d = max(dates)

    existing_rows = db.execute(text("""
        SELECT event_date, start_time, duration_minutes
        FROM calendar_events
        WHERE user_id = :uid
          AND event_date BETWEEN :start AND :end
          AND (plan_id IS NULL OR plan_id != :plan_id)
        ORDER BY event_date, start_time
    """), {"uid": user_id, "start": start_d, "end": end_d, "plan_id": plan_id}).fetchall()

    # 构建每天已占用的时间段集合 {(start_hour, end_hour)}
    daily_busy: dict[date, list[tuple[int, int]]] = {}
    for row in existing_rows:
        d = row.event_date if hasattr(row.event_date, 'isoformat') else date.fromisoformat(str(row.event_date))
        st_parts = str(row.start_time).split(':')
        sh = int(st_parts[0])
        dur = row.duration_minutes
        eh = sh + dur // 60 + (1 if dur % 60 else 0)
        daily_busy.setdefault(d, []).append((sh, eh))

    # 按日期分组
    by_date: dict[date, list[dict]] = {}
    for item in scheduled:
        d = item["planned_date"]
        by_date.setdefault(d, []).append(item)

    created = 0
    for d, items in by_date.items():
        busy = daily_busy.get(d, [])
        busy.sort()

        for item in items:
            minutes = item.get("estimated_minutes", 20)
            # 在已有事件之间找空隙，从 8:00 开始
            slot = _find_next_slot(busy, minutes, 8, 22)
            start_hour = slot

            if start_hour is None:
                logger.warning("日期 %s 无可用时间段，跳过", d)
                continue

            start_time_str = f"{start_hour:02d}:00"
            title = item.get("text", "学习任务")[:50]

            # 获取学科颜色
            subject_color = "#6366F1"
            if item.get("subject_id"):
                from database import Subject
                subj = db.query(Subject).filter_by(id=item["subject_id"]).first()
                if subj and hasattr(subj, "category") and subj.category:
                    subject_color = subj.category

            try:
                db.execute(text("""
                    INSERT INTO calendar_events
                        (user_id, title, event_date, start_time, duration_minutes,
                         subject_id, color, notes, is_completed, is_countdown,
                         priority, source, plan_id)
                    VALUES
                        (:uid, :title, :date, :start_time, :dur,
                         :subject_id, :color, :notes, FALSE, FALSE,
                         :priority, 'study-planner', :plan_id)
                """), {
                    "uid": user_id,
                    "title": title,
                    "date": d,
                    "start_time": start_time_str,
                    "dur": minutes,
                    "subject_id": item.get("subject_id"),
                    "color": subject_color,
                    "notes": f"plan_id={plan_id}",
                    "priority": item.get("priority", "medium"),
                    "plan_id": plan_id,
                })
                # 标记已占用
                end_h = start_hour + minutes // 60 + (1 if minutes % 60 else 0)
                busy.append((start_hour, end_h))
                busy.sort()
                created += 1
            except Exception as e:
                logger.warning("写入日历事件失败：%s", e)

    return created


def _find_next_slot(
    busy: list[tuple[int, int]],
    needed_minutes: int,
    min_hour: int,
    max_hour: int,
) -> Optional[int]:
    """
    在已占用时间段列表中找到下一个可用的开始小时。
    needed_minutes 转换为需要的"小时块"（向上取整）。
    返回开始小时（int），找不到返回 None。
    """
    needed_hours = needed_minutes // 60 + (1 if needed_minutes % 60 else 0)
    current = min_hour

    for busy_start, busy_end in busy:
        # 当前位置到 busy_start 之间有空隙
        if current + needed_hours <= busy_start:
            return current
        # 移动到 busy_end 之后
        if busy_end > current:
            current = busy_end

    # 检查最后一个 busy 之后
    if current + needed_hours <= max_hour:
        return current

    return None


# ── StudyPlannerService ───────────────────────────────────────────────────────

class StudyPlannerService:

    def generate_plan(
        self,
        plan_id: int,
        user_id: int,
        subject_ids: list[int],
        deadline: datetime,
        daily_minutes: int,
        db,
    ) -> bool:
        """
        Multi-Agent 规划流程：
        1. 并行 SubjectAgent（每学科一个线程，超时 30s）
        2. AcademicAgent 排期
        3. 批量写入 plan_items
        4. 更新 study_plan.status = 'active'
        返回 True 表示成功。
        """
        from database import StudyPlan, PlanItem, Subject

        subject_analyses = []
        failed_subjects = []

        # 并行 SubjectAgent
        with ThreadPoolExecutor(max_workers=min(len(subject_ids), 4)) as executor:
            futures = {
                executor.submit(_run_subject_agent, sid, user_id, db): sid
                for sid in subject_ids
            }
            for future in as_completed(futures, timeout=30):
                sid = futures[future]
                try:
                    result = future.result(timeout=30)
                    subject_analyses.append(result)
                except (FuturesTimeout, Exception) as e:
                    logger.warning("SubjectAgent 学科 %s 失败：%s", sid, e)
                    failed_subjects.append(sid)

        # 查询已有日历事件（感知"路况"）
        start = date.today()
        deadline_date = deadline.date() if hasattr(deadline, 'date') else deadline
        existing_events = _get_existing_calendar_events(user_id, start, deadline_date, db)
        if any(evts for evts in existing_events.values()):
            logger.info("排课前感知到 %d 天已有日历事件", sum(1 for evts in existing_events.values() if evts))

        # 排期：先尝试 Council Advisor 智能调度，失败降级到贪心算法
        # 两者都接收已有事件信息以避免冲突
        scheduled = _advisor_schedule_suggestion(
            subject_analyses, deadline, daily_minutes, start,
            existing_events=existing_events,
        )
        if not scheduled:
            scheduled = _schedule_items(
                subject_analyses, deadline, daily_minutes, start,
                existing_events=existing_events,
            )

        # 补全 scheduled 条目中的 subject_name（Advisor 返回的可能缺少）
        name_map = {a["subject_id"]: a.get("subject_name", "") for a in subject_analyses}
        for item in scheduled:
            if not item.get("subject_name"):
                item["subject_name"] = name_map.get(item.get("subject_id"), "")

        if not scheduled:
            logger.warning("generate_plan: 无可排期节点，plan_id=%s，学科分析=%s",
                           plan_id, [a.get('subject_name', '?') for a in subject_analyses])
            # 没有可排期的节点，不应该激活计划
            plan = db.query(StudyPlan).filter_by(id=plan_id).first()
            if plan:
                plan.status = 'draft'
                plan.items  # 确保关系加载
            return False

        # 批量写入 plan_items
        plan = db.query(StudyPlan).filter_by(id=plan_id).first()
        if not plan:
            return False

        for item in scheduled:
            planned_dt = datetime.combine(item['planned_date'], datetime.min.time()).replace(tzinfo=timezone.utc)
            db.add(PlanItem(
                plan_id=plan_id,
                subject_id=item['subject_id'],
                node_id=item['node_id'],
                node_text=item['text'][:256],
                estimated_minutes=item.get('estimated_minutes', 20),
                priority=item.get('priority', 'medium'),
                dependency_node_ids=item.get('parent_id') and [item['parent_id']] or [],
                planned_date=planned_dt,
                status='pending',
            ))

        plan.status = 'active'

        # 同步写入日历 calendar_events（排课结果可视化）
        calendar_count = _sync_plan_to_calendar(user_id, plan_id, scheduled, db)
        if calendar_count > 0:
            logger.info("generate_plan: 已将 %d 条排课写入日历，plan_id=%s", calendar_count, plan_id)

        db.flush()
        return True

    def sync_node_completion(
        self,
        user_id: int,
        node_id: str,
        db,
    ) -> None:
        """
        静默同步：节点点亮时自动更新对应 plan_item 状态。
        幂等：多次调用结果相同。
        """
        from database import StudyPlan, PlanItem

        # 找 active 计划
        active_plan = (
            db.query(StudyPlan)
            .filter_by(user_id=user_id, status='active')
            .first()
        )
        if not active_plan:
            return

        # 找对应 plan_item
        item = (
            db.query(PlanItem)
            .filter_by(plan_id=active_plan.id, node_id=node_id, status='pending')
            .first()
        )
        if not item:
            return

        item.status = 'done'
        item.completed_at = datetime.now(timezone.utc)
        db.flush()

        # 检查计划是否全部完成
        self.check_plan_completion(active_plan.id, db)

    def check_plan_completion(self, plan_id: int, db) -> bool:
        """检查计划是否全部完成，若是则更新状态为 completed。"""
        from database import StudyPlan, PlanItem

        plan = db.query(StudyPlan).filter_by(id=plan_id).first()
        if not plan or plan.status != 'active':
            return False

        pending = (
            db.query(PlanItem)
            .filter_by(plan_id=plan_id, status='pending')
            .count()
        )
        if pending == 0:
            plan.status = 'completed'
            db.flush()
            return True
        return False
