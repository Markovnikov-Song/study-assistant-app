# backend/skill_ecosystem/marketplace_service.py
"""
Skill 市场核心服务（内存存储，后续迁移到数据库）。
  - list_skills：只返回通过结构验证的 Skill，分页每页最多 20 条
  - download_skill：返回带 marketplace_download 来源标注的 SkillSchema
  - submit_skill：分配新 UUID，来源标注 third_party_api
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from skill_ecosystem.models import (
    MarketplaceSkillSchema,
    PaginatedSkillList,
    PromptNodeSchema,
    SkillSchema,
    SkillSourceEnum,
    SkillSubmitRequest,
)


def _is_valid_skill(skill: MarketplaceSkillSchema) -> bool:
    """结构验证：prompt_chain 非空且所有必填字段存在（属性 12）。"""
    if not skill.prompt_chain:
        return False
    if not skill.name or not skill.description:
        return False
    return True


# ── 预置内置 Skill（从 SkillRegistry 加载，避免维护两份）────────────────────

def _make_builtin_skills() -> dict[str, MarketplaceSkillSchema]:
    """从 SkillRegistry 加载内置 Skill，转换为 MarketplaceSkillSchema 格式。"""
    from skill_registry import get_registry

    skills: dict[str, MarketplaceSkillSchema] = {}
    now = datetime.utcnow()

    # 市场展示用的下载量（静态初始值）
    _download_counts = {
        "skill_feynman": 1280,
        "skill_spaced_repetition": 980,
        "skill_problem_solving": 756,
        "skill_mindmap_learning": 612,
        "skill_exam_prep": 445,
    }

    for raw in get_registry().list_skills():
        skill_id = raw["id"]
        # 市场 ID 用 mkt_ 前缀，与执行 ID 区分
        mkt_id = "mkt_" + skill_id.replace("skill_", "")
        prompt_chain = [
            PromptNodeSchema(
                id=node["id"],
                prompt=node["prompt"],
                input_mapping=node.get("inputMapping") or {},
            )
            for node in raw.get("promptChain", [])
        ]
        skill = MarketplaceSkillSchema(
            id=mkt_id,
            name=raw["name"],
            description=raw["description"],
            tags=raw.get("tags", []),
            prompt_chain=prompt_chain,
            required_components=raw.get("requiredComponents", []),
            version=raw.get("version", "1.0.0"),
            created_at=now,
            type=raw.get("type", "builtin"),
            source=SkillSourceEnum.builtin,
            download_count=_download_counts.get(skill_id, 0),
            submitted_at=now,
        )
        skills[skill.id] = skill

    return skills


# ── 内存存储 ───────────────────────────────────────────────────────────────────

_marketplace_skills: dict[str, MarketplaceSkillSchema] = _make_builtin_skills()


# ── MarketplaceService ─────────────────────────────────────────────────────────


class MarketplaceService:
    """Skill 市场核心服务（内存存储）。"""

    def list_skills(
        self,
        tag: Optional[str] = None,
        keyword: Optional[str] = None,
        source: Optional[str] = None,
        sort_by: str = "download_count",
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedSkillList:
        """
        只返回通过结构验证的 Skill，分页每页最多 20 条（属性 12）。
        需求 6.1、6.2、6.5。
        """
        # 强制每页最多 20 条
        page_size = min(page_size, 20)
        page = max(page, 1)

        # 过滤：只保留结构有效的 Skill
        skills = [s for s in _marketplace_skills.values() if _is_valid_skill(s)]

        # 按 tag 过滤
        if tag:
            skills = [s for s in skills if tag in s.tags]

        # 按 keyword 过滤（名称或描述）
        if keyword:
            kw = keyword.lower()
            skills = [
                s for s in skills
                if kw in s.name.lower() or kw in s.description.lower()
            ]

        # 按 source 过滤
        if source:
            skills = [s for s in skills if s.source.value == source]

        # 排序
        if sort_by == "download_count":
            skills.sort(key=lambda s: s.download_count, reverse=True)
        elif sort_by == "submitted_at":
            skills.sort(
                key=lambda s: s.submitted_at or datetime.min,
                reverse=True,
            )
        elif sort_by == "name":
            skills.sort(key=lambda s: s.name)

        total = len(skills)
        start = (page - 1) * page_size
        end = start + page_size
        page_skills = skills[start:end]

        return PaginatedSkillList(
            skills=page_skills,
            total=total,
            page=page,
            page_size=page_size,
        )

    def get_skill(self, marketplace_skill_id: str) -> Optional[MarketplaceSkillSchema]:
        """获取单个 Skill 完整定义。"""
        return _marketplace_skills.get(marketplace_skill_id)

    def download_skill(
        self,
        marketplace_skill_id: str,
        user_id: str,
    ) -> SkillSchema:
        """
        下载云端 Skill 到用户本地库。
        来源标注为 marketplace_download，记录原始云端 ID 和下载时间（属性 11）。
        需求 6.3。
        """
        original = _marketplace_skills.get(marketplace_skill_id)
        if original is None:
            raise KeyError(f"Skill '{marketplace_skill_id}' 不存在")

        # 增加下载计数
        _marketplace_skills[marketplace_skill_id] = original.model_copy(
            update={"download_count": original.download_count + 1}
        )

        # 返回带 marketplace_download 来源标注的本地副本
        now = datetime.utcnow()
        local_skill = SkillSchema(
            id=str(uuid.uuid4()),
            name=original.name,
            description=original.description,
            tags=list(original.tags),
            prompt_chain=list(original.prompt_chain),
            required_components=list(original.required_components),
            version=original.version,
            created_at=now,
            type=original.type,
            source=SkillSourceEnum.marketplace_download,
            created_by=user_id,
            schema_version=original.schema_version,
        )
        return local_skill

    def submit_skill(
        self,
        skill_data: SkillSubmitRequest,
        submitter_id: str,
    ) -> MarketplaceSkillSchema:
        """
        第三方提交 Skill。
        分配新 UUID，来源标注 third_party_api。
        验证失败时调用方应返回 422。
        需求 7.1–7.6。
        """
        now = datetime.utcnow()
        new_id = str(uuid.uuid4())

        skill = MarketplaceSkillSchema(
            id=new_id,
            name=skill_data.name,
            description=skill_data.description,
            tags=list(skill_data.tags),
            prompt_chain=list(skill_data.prompt_chain),
            required_components=list(skill_data.required_components),
            version=skill_data.version,
            created_at=now,
            type="custom",
            source=SkillSourceEnum.third_party_api,
            created_by=submitter_id,
            schema_version="1.0",
            download_count=0,
            submitter_id=submitter_id,
            submitted_at=now,
        )

        _marketplace_skills[new_id] = skill
        return skill


# ── 单例 ───────────────────────────────────────────────────────────────────────

_service_instance: Optional[MarketplaceService] = None


def get_marketplace_service() -> MarketplaceService:
    global _service_instance
    if _service_instance is None:
        _service_instance = MarketplaceService()
    return _service_instance
