"""
MemoryService — 用户学习记忆画像的读写与更新。
"""
from __future__ import annotations

import json
from typing import Optional

from backend_config import get_config
from database import UserMemory, get_session


class MemoryService:
    def __init__(self):
        self._cfg = get_config()

    def get_memory(self, user_id: int, subject_id: Optional[int] = None) -> dict:
        with get_session() as db:
            m = db.query(UserMemory).filter_by(
                user_id=user_id, subject_id=subject_id
            ).first()
            return m.memory if m else {}

    def update_memory(
        self, user_id: int, subject_id: Optional[int], conversation_text: str
    ) -> None:
        """从对话文本中提取记忆并更新。"""
        from services.llm_service import LLMService

        cfg = self._cfg
        prompt = (
            "请从以下对话中提取用户的学习特征，以 JSON 格式返回：\n"
            "{\n"
            f'  "weak_points": ["最多{cfg.MEMORY_WEAK_POINTS_MAX}个薄弱知识点"],\n'
            f'  "frequent_topics": ["最多{cfg.MEMORY_FREQUENT_TOPICS_MAX}个常问话题"],\n'
            f'  "misconceptions": ["最多{cfg.MEMORY_MISCONCEPTIONS_MAX}个误解"],\n'
            '  "summary": "一句话总结用户学习特征"\n'
            "}\n"
            "只返回 JSON，不要其他内容。\n\n"
            f"对话内容：\n{conversation_text[:3000]}"
        )
        try:
            raw = LLMService().chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=cfg.LLM_MEMORY_TEMPERATURE,
                max_tokens=cfg.LLM_MEMORY_MAX_TOKENS,
            )
            raw = raw.strip()
            if raw.startswith("```"):
                lines = raw.splitlines()
                raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
            new_memory = json.loads(raw)
        except Exception:
            return

        with get_session() as db:
            m = db.query(UserMemory).filter_by(
                user_id=user_id, subject_id=subject_id
            ).first()
            if m:
                m.memory = new_memory
            else:
                db.add(UserMemory(
                    user_id=user_id,
                    subject_id=subject_id,
                    memory=new_memory,
                ))
