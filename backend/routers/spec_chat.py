"""
spec_chat.py — LLM 对话式学习规划参数收集

职责：
  - POST /api/spec/chat  — 接收用户自然语言消息，LLM 提取规划参数（学科/日期/时长）
  - 内存级 session 管理（user_id → 对话历史 + 已收集参数）
  - 参数齐备后返回 ready=true + 结构化参数
  - LLM 失败自动降级，返回 missing_slots 提示前端展示 ParamFillCard

与 PhaseChatView 旧的硬编码 4 步表单向导相比：
  - 用户一句话就能提供所有参数，如"高数和线代，期末前，每天2小时"
  - 支持自然语言日期（"下个月"、"期末"等）
  - 多轮对话，缺少的参数由 LLM 主动追问
"""
from __future__ import annotations

import json
import logging
import re
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from database import Subject, get_session as db_session
from deps import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

# ── 内存级 session 存储 ──────────────────────────────────────────────────────
# key: user_id → {messages, collected, session_id}
_sessions: Dict[int, dict] = {}


def _get_session(user_id: int) -> dict:
    if user_id not in _sessions:
        _sessions[user_id] = {
            "messages": [],
            "collected": {},   # subject_ids, subject_names, deadline, daily_minutes
            "ready": False,
        }
    return _sessions[user_id]


def _clear_session(user_id: int) -> None:
    _sessions.pop(user_id, None)


def _parse_date_flexible(text: str) -> Optional[date]:
    """
    解析灵活的日期表达，支持：
    - ISO: 2025-06-30, 2025/06/30
    - 相对: 下个月, 30天后, 两周后, 期末（默认+60天）
    """
    text = text.strip()
    today = date.today()

    # ISO 格式
    for sep in ["-", "/"]:
        if sep in text:
            try:
                return date.fromisoformat(text.replace("/", "-"))
            except ValueError:
                pass

    # "X天后" / "X天以后"
    m = re.search(r"(\d+)\s*天[以之]后", text)
    if m:
        try:
            return today + timedelta(days=int(m.group(1)))
        except (ValueError, OverflowError):
            pass

    # "X周后" / "X周以后"
    m = re.search(r"(\d+)\s*周[以之]后", text)
    if m:
        try:
            return today + timedelta(weeks=int(m.group(1)))
        except (ValueError, OverflowError):
            pass

    # "X个月" / "X个月后"
    m = re.search(r"(\d+)\s*个?月[以之]后", text)
    if m:
        try:
            from calendar import monthrange
            months = int(m.group(1))
            target_month = today.month + months
            target_year = today.year + (target_month - 1) // 12
            target_month = (target_month - 1) % 12 + 1
            _, last_day = monthrange(target_year, target_month)
            return date(target_year, target_month, min(today.day, last_day))
        except (ValueError, OverflowError):
            pass

    # "下个月"
    if "下个月" in text:
        from calendar import monthrange
        target_month = today.month + 1
        target_year = today.year + (target_month - 1) // 12
        target_month = (target_month - 1) % 12 + 1
        _, last_day = monthrange(target_year, target_month)
        return date(target_year, target_month, min(today.day, last_day))

    # "两周后" / "两周以后"
    if "两周" in text or "两周" in text:
        return today + timedelta(weeks=2)

    # "下周"
    if "下周" in text:
        return today + timedelta(weeks=1)

    # "期末" / "考试" — 默认 60 天后
    if "期末" in text or "考试" in text:
        return today + timedelta(days=60)

    return None


def _parse_duration(text: str) -> Optional[int]:
    """解析时长表达，返回分钟数。支持：2小时, 90分钟, 1.5h 等。"""
    text = text.strip()

    # "X小时" / "X个小时" / "X h"
    m = re.search(r"(\d+\.?\d*)\s*(?:个?小时|h|hours?)", text, re.IGNORECASE)
    if m:
        return max(15, min(480, int(float(m.group(1)) * 60)))

    # "X分钟" / "X分钟" / "X min"
    m = re.search(r"(\d+)\s*(?:分钟|min)", text, re.IGNORECASE)
    if m:
        return max(15, min(480, int(m.group(1))))

    # "X个半小时" = 30 分钟
    m = re.search(r"半个?小时", text)
    if m:
        return 30

    return None


# ── Pydantic 模型 ──────────────────────────────────────────────────────────────

class ChatMessageIn(BaseModel):
    message: str = Field(..., min_length=1, max_length=500, description="用户消息")
    session_id: Optional[str] = Field(None, description="会话ID，用于恢复历史")


class ChatMessageOut(BaseModel):
    reply: str                           # LLM 的自然语言回复
    ready: bool = False                  # 参数是否已齐备
    collected: Optional[Dict[str, Any]] = None  # {subject_ids, subject_names, deadline, daily_minutes}
    missing_slots: Optional[List[str]] = None    # 缺少的参数列表
    session_id: Optional[str] = None     # 会话ID


class ResetSessionIn(BaseModel):
    pass


# ── LLM 提取逻辑 ──────────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """你是一个学习规划助教，负责通过对话收集学生的学习规划参数。

你需要从用户的自然语言中提取以下信息：
1. **学科**（subject_ids）— 用户要复习/备考的科目列表
2. **截止日期**（deadline）— ISO 格式 YYYY-MM-DD
3. **每日学习时长**（daily_minutes）— 整数分钟

【当前用户可选学科列表】
{subject_list}

【已收集到的信息】
{collected_info}

【规则】
- 如果用户提供了某个参数，提取并确认
- 如果缺少参数，自然地追问，不要用列表形式
- 回复要简洁友好，像朋友一样
- 如果用户说的是日期口语（如"下个月"、"期末前"），转换为 YYYY-MM-DD
- 如果用户说的时间是小时，转换为分钟（如"2小时"→120）
- 每次回复末尾用一行 JSON 标记提取结果，格式：```json
{"subject_ids": [1,2], "subject_names": ["高数","线代"], "deadline": "2025-06-30", "daily_minutes": 120}
```
缺少的字段用 null。如果参数已齐备（三个字段都不为null），在 JSON 里加 "ready": true。
只输出自然语言回复 + JSON 标记，不要输出其他格式。"""


def _build_llm_messages(user_id: int, session: dict, user_message: str, subjects: list) -> list:
    """构建给 LLM 的消息列表。"""
    subject_list = "\n".join(f"  - ID={s.id}, 名称={s.name}" for s in subjects) or "  （暂无学科）"

    collected = session["collected"]
    collected_info_parts = []
    if collected.get("subject_ids"):
        names = collected.get("subject_names", [])
        collected_info_parts.append(f"- 学科：{', '.join(names)}（IDs: {collected['subject_ids']}）")
    if collected.get("deadline"):
        collected_info_parts.append(f"- 截止日期：{collected['deadline']}")
    if collected.get("daily_minutes"):
        h = collected["daily_minutes"] / 60
        collected_info_parts.append(f"- 每日学习时长：{collected['daily_minutes']}分钟（{h:.1f}小时）")
    collected_info = "\n".join(collected_info_parts) if collected_info_parts else "（尚无）"

    system_msg = _SYSTEM_PROMPT.format(
        subject_list=subject_list,
        collected_info=collected_info,
    )

    messages = [{"role": "system", "content": system_msg}]

    # 对话历史（最近 10 条）
    for msg in session["messages"][-10:]:
        messages.append(msg)

    # 当前用户消息
    messages.append({"role": "user", "content": user_message})

    return messages


def _extract_json_block(text: str) -> Optional[dict]:
    """从 LLM 回复中提取 ```json ... ``` 块。"""
    m = re.search(r"```json\s*\n?(.*?)\n?\s*```", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(1).strip())
        except json.JSONDecodeError:
            pass
    return None


def _local_fallback_extract(user_message: str, subjects: list) -> dict:
    """
    本地规则兜底：尝试从用户消息中提取参数（不调用 LLM）。
    返回 collected dict。
    """
    collected: Dict[str, Any] = {}

    # 提取学科
    matched_subjects = []
    for s in subjects:
        if s.name in user_message:
            matched_subjects.append(s)
        # 也匹配简称
        for alias in _get_subject_aliases(s.name):
            if alias in user_message and s not in matched_subjects:
                matched_subjects.append(s)

    if matched_subjects:
        collected["subject_ids"] = [s.id for s in matched_subjects]
        collected["subject_names"] = [s.name for s in matched_subjects]

    # 提取日期
    parsed_date = _parse_date_flexible(user_message)
    if parsed_date and parsed_date > date.today():
        collected["deadline"] = parsed_date.isoformat()

    # 提取时长
    parsed_minutes = _parse_duration(user_message)
    if parsed_minutes:
        collected["daily_minutes"] = parsed_minutes

    return collected


def _get_subject_aliases(name: str) -> list[str]:
    """获取学科的常见别名。"""
    aliases = {
        "高等数学": ["高数", "微积分", "高数上", "高数下"],
        "线性代数": ["线代", "线代数"],
        "概率论与数理统计": ["概率论", "概率", "概率统计", "数理统计"],
        "大学物理": ["大物", "物理"],
        "大学英语": ["英语", "大英", "四六级", "CET"],
        "数据结构": ["DS", "数据结构与算法"],
        "计算机网络": ["计网", "网络"],
        "操作系统": ["OS", "系统"],
        "材料力学": ["材力"],
        "理论力学": ["理力"],
    }
    for full_name, alias_list in aliases.items():
        if name == full_name or full_name in name:
            return alias_list
    return []


def _check_ready(collected: dict) -> bool:
    """检查三个必需参数是否齐全。"""
    return (
        collected.get("subject_ids")
        and collected.get("deadline")
        and collected.get("daily_minutes")
    )


def _get_missing_slots(collected: dict) -> list[str]:
    """返回缺少的参数列表（中文）。"""
    missing = []
    if not collected.get("subject_ids"):
        missing.append("subject_ids")
    if not collected.get("deadline"):
        missing.append("deadline")
    if not collected.get("daily_minutes"):
        missing.append("daily_minutes")
    return missing


# ── 端点 ───────────────────────────────────────────────────────────────────────

@router.post("/chat", response_model=ChatMessageOut)
def spec_chat(body: ChatMessageIn, user=Depends(get_current_user)):
    """
    对话式学习规划参数收集。
    - 用户发送自然语言消息
    - 后端用 LLM 提取 subject_ids / deadline / daily_minutes
    - 参数齐备后返回 ready=true
    - LLM 失败时自动降级到本地规则提取
    """
    user_id = int(user["id"])
    session = _get_session(user_id)

    # 获取用户学科列表
    with db_session() as db:
        subjects = db.query(Subject).filter_by(user_id=user_id).all()

    if not subjects:
        raise HTTPException(400, "请先在「我的」页面添加学科")

    # 记录用户消息
    session["messages"].append({"role": "user", "content": body.message})

    # ── 尝试 LLM 提取 ────────────────────────────────────────────────────
    reply_text = ""
    extracted = {}
    llm_ok = False

    try:
        from services.llm_service import LLMService
        from backend_config import get_config

        messages = _build_llm_messages(user_id, session, body.message, subjects)
        llm = LLMService()
        cfg = get_config()

        raw = llm.chat(
            messages,
            user_id=user_id,
            endpoint="spec_chat",
            max_tokens=256,
            temperature=0.7,
        )

        # 提取 JSON 块
        extracted = _extract_json_block(raw) or {}

        # 去掉 JSON 块，保留自然语言回复
        reply_text = re.sub(r"```json\s*\n?.*?\n?\s*```", "", raw, flags=re.DOTALL).strip()
        if not reply_text:
            reply_text = "好的，我理解了。"

        llm_ok = True
    except Exception as e:
        logger.warning("spec_chat LLM 调用失败，降级到本地规则：%s", e)

    # ── LLM 失败时本地规则兜底 ────────────────────────────────────────────
    if not llm_ok:
        local = _local_fallback_extract(body.message, subjects)
        if local:
            extracted = local

        if extracted:
            parts = []
            if extracted.get("subject_names"):
                parts.append(f"学科：{', '.join(extracted['subject_names'])}")
            if extracted.get("deadline"):
                parts.append(f"截止日期：{extracted['deadline']}")
            if extracted.get("daily_minutes"):
                parts.append(f"每日学习时长：{extracted['daily_minutes']}分钟")
            reply_text = "好的，已记录：" + "、".join(parts) + "。"
        else:
            reply_text = "我没太理解，你能再说一下吗？比如你可以说：\"高数，6月30日前，每天2小时\""

    # ── 合并到 collected ─────────────────────────────────────────────────
    if extracted.get("subject_ids"):
        session["collected"]["subject_ids"] = extracted["subject_ids"]
    if extracted.get("subject_names"):
        session["collected"]["subject_names"] = extracted["subject_names"]
    if extracted.get("deadline"):
        session["collected"]["deadline"] = extracted["deadline"]
    if extracted.get("daily_minutes"):
        session["collected"]["daily_minutes"] = extracted["daily_minutes"]

    # 检查是否就绪
    is_ready = _check_ready(session["collected"])
    session["ready"] = is_ready

    # 记录助手回复
    session["messages"].append({"role": "assistant", "content": reply_text})

    # 构造响应
    collected_out = None
    if is_ready:
        collected_out = session["collected"]
    elif not llm_ok and not extracted:
        # 本地规则也没提取到，告诉前端缺少什么
        pass

    missing = _get_missing_slots(session["collected"])

    return ChatMessageOut(
        reply=reply_text,
        ready=is_ready,
        collected=collected_out,
        missing_slots=missing if not is_ready else None,
        session_id=str(user_id),
    )


@router.post("/chat/reset")
def spec_chat_reset(user=Depends(get_current_user)):
    """重置对话会话。"""
    user_id = int(user["id"])
    _clear_session(user_id)
    return {"ok": True}
