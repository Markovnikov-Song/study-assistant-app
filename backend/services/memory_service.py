"""
MemoryService — 用户学习记忆画像的读写与更新。

改进点：
1. 增量合并：新记忆与旧记忆智能合并，而非全量覆盖
2. 时间衰减：长时间未出现的知识点会被弱化
3. 置信度追踪：记录每个记忆点的置信度
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Optional, List

from backend_config import get_config
from database import UserMemory, get_session


class MemoryService:
    """用户学习记忆服务 - 支持增量合并"""

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
        """从对话文本中提取记忆并增量合并。"""
        from services.llm_service import LLMService

        cfg = self._cfg
        
        # 使用完整对话文本，不再截断
        prompt = (
            "请从以下对话中提取用户的学习特征，以 JSON 格式返回：\n"
            "{\n"
            f'  "weak_points": ["最多{cfg.MEMORY_WEAK_POINTS_MAX}个薄弱知识点"],\n'
            f'  "frequent_topics": ["最多{cfg.MEMORY_FREQUENT_TOPICS_MAX}个常问话题"],\n'
            f'  "misconceptions": ["最多{cfg.MEMORY_MISCONCEPTIONS_MAX}个误解"],\n'
            '  "summary": "一句话总结用户学习特征"\n'
            "}\n"
            "只返回 JSON，不要其他内容。\n\n"
            f"对话内容：\n{conversation_text}"
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
                # 增量合并，而非全量覆盖
                old_memory = m.memory or {}
                merged = self._merge_memory(old_memory, new_memory)
                m.memory = merged
            else:
                # 新记忆，添加元数据
                new_memory["_meta"] = {
                    "created_at": datetime.now(timezone.utc).isoformat(),
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
                db.add(UserMemory(
                    user_id=user_id,
                    subject_id=subject_id,
                    memory=new_memory,
                ))

    def _merge_memory(self, old: dict, new: dict) -> dict:
        """
        智能合并新旧记忆。
        
        策略：
        1. 新出现的知识点直接添加
        2. 旧知识点如果被再次提及，置信度+1
        3. 旧知识点如果未被提及，置信度-1（但保留）
        4. 每个列表最多保留 N 条（configurable）
        """
        merged = old.copy()
        now = datetime.now(timezone.utc).isoformat()
        
        # 确保 _meta 存在
        if "_meta" not in merged:
            merged["_meta"] = {"created_at": now, "updated_at": now}
        merged["_meta"]["updated_at"] = now
        
        # 定义需要合并的列表字段及其最大数量
        list_fields = {
            "weak_points": self._cfg.MEMORY_WEAK_POINTS_MAX,
            "frequent_topics": self._cfg.MEMORY_FREQUENT_TOPICS_MAX,
            "misconceptions": self._cfg.MEMORY_MISCONCEPTIONS_MAX,
        }
        
        for field, max_items in list_fields.items():
            old_items = merged.get(f"_{field}_data", {})  # 带置信度的数据
            new_items = new.get(field, [])
            
            # 合并逻辑
            merged_items = self._merge_list_with_confidence(
                old_items, new_items, max_items
            )
            merged[field] = list(merged_items.keys())
            merged[f"_{field}_data"] = merged_items
        
        # 更新 summary
        if new.get("summary"):
            merged["summary"] = new["summary"]
        
        return merged

    def _merge_list_with_confidence(
        self, old_data: dict, new_items: List[str], max_items: int
    ) -> dict:
        """
        带置信度的列表合并。
        
        Args:
            old_data: 旧数据 {item: confidence} 格式
            new_items: 新提取的列表
            max_items: 最大保留数量
        
        Returns:
            合并后的 {item: confidence} 字典
        """
        result = {}
        
        # 1. 新出现的项目，初始置信度 +1
        for item in new_items:
            normalized = self._normalize_topic(item)
            if normalized in old_data:
                # 已存在：置信度 +1
                result[normalized] = min(10, old_data[normalized] + 1)
            else:
                # 新出现：初始置信度 3（表示被 LLM 明确提取）
                result[normalized] = 3
        
        # 2. 旧项目未被提及，置信度 -1
        all_old = set(old_data.keys())
        all_new = set(self._normalize_topic(i) for i in new_items)
        not_mentioned = all_old - all_new
        
        for item in not_mentioned:
            # 置信度 -1，但不删除（可能还有价值）
            new_conf = old_data[item] - 1
            if new_conf > 0:  # 只保留置信度 > 0 的
                result[item] = new_conf
        
        # 3. 按置信度排序，取前 max_items 条
        sorted_items = sorted(result.items(), key=lambda x: -x[1])
        return dict(sorted_items[:max_items])

    def _normalize_topic(self, topic: str) -> str:
        """标准化知识点名称，便于去重比较"""
        return topic.strip().lower()

    def get_weak_points(self, user_id: int, subject_id: Optional[int] = None) -> List[dict]:
        """
        获取薄弱知识点（带置信度）。
        
        Returns:
            [{"topic": "...", "confidence": 5, "updated_at": "..."}]
        """
        memory = self.get_memory(user_id, subject_id)
        weak_data = memory.get("_weak_points_data", {})
        meta = memory.get("_meta", {})
        
        result = []
        for topic, conf in weak_data.items():
            result.append({
                "topic": topic,
                "confidence": conf,
                "updated_at": meta.get("updated_at"),
            })
        
        return sorted(result, key=lambda x: -x["confidence"])

    def decay_confidence(self, user_id: int, days: int = 7) -> None:
        """
        对长时间未更新的记忆进行置信度衰减。
        
        建议定时调用（如每周一次）：
        - 超过 7 天未更新的记忆，置信度 -1
        """
        with get_session() as db:
            memories = db.query(UserMemory).filter(
                UserMemory.user_id == user_id
            ).all()
            
            now = datetime.now(timezone.utc)
            for m in memories:
                mem = m.memory or {}
                meta = mem.get("_meta", {})
                
                if not meta:
                    continue
                
                try:
                    updated_at = datetime.fromisoformat(meta["updated_at"].replace("Z", "+00:00"))
                    days_since_update = (now - updated_at).days
                except (ValueError, KeyError):
                    continue
                    
                if days_since_update > days:
                    # 衰减所有列表字段的置信度
                    for field in ["weak_points", "frequent_topics", "misconceptions"]:
                        data_key = f"_{field}_data"
                        if data_key in mem:
                            decayed = {}
                            for item, conf in mem[data_key].items():
                                new_conf = conf - 1
                                if new_conf > 0:
                                    decayed[item] = new_conf
                            mem[data_key] = decayed
                            mem[field] = list(decayed.keys())
                    
                    # 更新 meta
                    mem["_meta"]["updated_at"] = now.isoformat()
                    m.memory = mem
                    
        db.flush()
