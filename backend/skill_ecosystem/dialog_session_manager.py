# backend/skill_ecosystem/dialog_session_manager.py
"""
对话式 Skill 创建会话管理器。
  - 内存存储 _sessions
  - AI 不可用时自动切换到 FALLBACK_QUESTIONS 硬编码序列，用户无感知
  - 支持中断恢复（save_draft）
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from skill_ecosystem.models import (
    DialogSession,
    DialogTurn,
    PromptNodeSchema,
    SkillDraftSchema,
    SkillSchema,
    SkillSourceEnum,
)

# ── 硬编码兜底问题序列 ─────────────────────────────────────────────────────────

FALLBACK_QUESTIONS = [
    "你想创建一个什么类型的学习方法？（例如：复习、解题、记忆）",
    "这个学习方法的第一步是什么？",
    "第一步完成后，下一步做什么？",
    "还有其他步骤吗？如果没有，请回复「完成」",
    "这个方法适合哪些学科？（例如：数学、物理、通用）",
    "给这个学习方法起一个名字吧",
]

# ── 内存存储 ───────────────────────────────────────────────────────────────────

_sessions: dict[str, DialogSession] = {}


# ── DialogSessionManager ───────────────────────────────────────────────────────


class DialogSessionManager:
    """
    管理对话式 Skill 创建的会话状态。
    AI 不可用时使用 FALLBACK_QUESTIONS 硬编码序列，用户无感知（属性 16）。
    """

    def start_session(self, user_id: str) -> DialogTurn:
        """
        启动新的对话会话，返回第一个问题。
        需求 9.1。
        """
        is_ai_available = self._check_ai_available()
        session = DialogSession(
            user_id=user_id,
            current_step=0,
            collected_data={},
            draft=SkillDraftSchema(),
            is_ai_available=is_ai_available,
        )
        _sessions[session.session_id] = session

        first_question = self._get_question(session, 0)
        return DialogTurn(
            session_id=session.session_id,
            question=first_question,
            draft_preview=None,
            is_complete=False,
        )

    def process_answer(self, session_id: str, answer: str) -> DialogTurn:
        """
        处理用户回答，返回下一个问题或草稿预览。
        收集到至少一个步骤后自动生成草稿预览（需求 9.3）。
        需求 9.2。
        """
        session = _sessions.get(session_id)
        if session is None:
            raise KeyError(f"Dialog session '{session_id}' 不存在")

        step = session.current_step
        answer = answer.strip()

        # 根据当前步骤收集数据
        self._collect_answer(session, step, answer)

        # 更新步骤
        next_step = step + 1
        session.current_step = next_step
        session.updated_at = datetime.utcnow()

        # 重新构建草稿
        draft = self._build_draft(session)
        session.draft = draft

        # 判断是否完成（FALLBACK_QUESTIONS 共 6 步，索引 0-5）
        total_steps = len(FALLBACK_QUESTIONS)
        is_complete = next_step >= total_steps or self._is_done_signal(answer)

        # 收集到至少一个步骤后展示草稿预览（需求 9.3）
        draft_preview: Optional[SkillDraftSchema] = None
        if draft.steps:
            draft_preview = draft

        if is_complete:
            return DialogTurn(
                session_id=session_id,
                question="太棒了！你的学习方法已经创建好了，请确认下方草稿。",
                draft_preview=draft,
                is_complete=True,
            )

        next_question = self._get_question(session, next_step)
        return DialogTurn(
            session_id=session_id,
            question=next_question,
            draft_preview=draft_preview,
            is_complete=False,
        )

    def save_draft(self, session_id: str) -> SkillDraftSchema:
        """
        将当前对话进度保存为草稿，支持中断恢复（属性 15）。
        需求 9.5。
        """
        session = _sessions.get(session_id)
        if session is None:
            raise KeyError(f"Dialog session '{session_id}' 不存在")

        draft = self._build_draft(session)
        session.draft = draft
        session.updated_at = datetime.utcnow()
        return draft

    def confirm_and_publish(self, session_id: str, user_id: str) -> SkillSchema:
        """
        用户确认草稿后，调用 SkillLibrary 保存并发布。
        需求 9.4、9.6。
        """
        session = _sessions.get(session_id)
        if session is None:
            raise KeyError(f"Dialog session '{session_id}' 不存在")

        draft = self._build_draft(session)

        # 构建正式 SkillSchema
        skill = SkillSchema(
            id=str(uuid.uuid4()),
            name=draft.name or "未命名学习方法",
            description=draft.description or "",
            tags=list(draft.tags),
            prompt_chain=list(draft.steps),
            required_components=list(draft.required_components),
            version="1.0.0",
            created_at=datetime.utcnow(),
            type="custom",
            source=SkillSourceEnum.user_created,
            created_by=user_id,
            schema_version="1.0",
        )

        # 清理会话
        _sessions.pop(session_id, None)
        return skill

    def delete_session(self, session_id: str) -> None:
        """放弃当前 Dialog_Session。需求 9.6。"""
        if session_id not in _sessions:
            raise KeyError(f"Dialog session '{session_id}' 不存在")
        _sessions.pop(session_id)

    # ── 内部方法 ───────────────────────────────────────────────────────────────

    def _check_ai_available(self) -> bool:
        """检查 AI 服务是否可用。"""
        try:
            from services.llm_service import LLMService
            LLMService()  # 仅检查能否实例化
            return True
        except Exception:
            return False

    def _get_question(self, session: DialogSession, step: int) -> str:
        """
        获取指定步骤的问题。
        AI 不可用时使用 FALLBACK_QUESTIONS（属性 16）。
        """
        # 当前阶段统一使用 FALLBACK_QUESTIONS（AI 引导问题生成为后续扩展）
        if step < len(FALLBACK_QUESTIONS):
            return FALLBACK_QUESTIONS[step]
        return "还有什么想补充的吗？如果没有，请回复「完成」"

    def _collect_answer(self, session: DialogSession, step: int, answer: str) -> None:
        """根据步骤将回答存入 collected_data。"""
        data = session.collected_data

        if step == 0:
            # 学习方法类型
            data["type_description"] = answer
        elif step == 1:
            # 第一步
            steps: list[str] = data.get("steps", [])
            steps.append(answer)
            data["steps"] = steps
        elif step == 2:
            # 第二步
            steps = data.get("steps", [])
            steps.append(answer)
            data["steps"] = steps
        elif step == 3:
            # 更多步骤或"完成"
            if not self._is_done_signal(answer):
                steps = data.get("steps", [])
                steps.append(answer)
                data["steps"] = steps
        elif step == 4:
            # 适合学科（标签）
            tags = [t.strip() for t in answer.replace("、", ",").replace("，", ",").split(",") if t.strip()]
            data["tags"] = tags
        elif step == 5:
            # 名称
            data["name"] = answer

    def _build_draft(self, session: DialogSession) -> SkillDraftSchema:
        """从 collected_data 构建 SkillDraftSchema。"""
        data = session.collected_data
        steps_text: list[str] = data.get("steps", [])

        prompt_nodes = [
            PromptNodeSchema(
                id=f"node_{i}",
                prompt=step_text,
                input_mapping={},
            )
            for i, step_text in enumerate(steps_text)
        ]

        name = data.get("name")
        tags = list(data.get("tags", []))
        type_desc = data.get("type_description", "")

        # 自动生成描述
        description: Optional[str] = None
        if type_desc:
            description = f"一种{type_desc}类型的学习方法"

        return SkillDraftSchema(
            session_id=session.session_id,
            name=name,
            description=description,
            tags=tags,
            steps=prompt_nodes,
            required_components=[],
            is_draft=True,
        )

    @staticmethod
    def _is_done_signal(answer: str) -> bool:
        """判断用户是否回复了"完成"信号。"""
        done_signals = {"完成", "done", "finish", "结束", "没有了", "没有", "no", "无"}
        return answer.strip().lower() in done_signals


# ── 单例 ───────────────────────────────────────────────────────────────────────

_manager_instance: Optional[DialogSessionManager] = None


def get_session_manager() -> DialogSessionManager:
    global _manager_instance
    if _manager_instance is None:
        _manager_instance = DialogSessionManager()
    return _manager_instance
