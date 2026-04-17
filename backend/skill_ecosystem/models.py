# backend/skill_ecosystem/models.py
"""Skill 生态扩展层 Pydantic 数据模型。"""
from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


# ── 枚举 ──────────────────────────────────────────────────────────────────────


class SkillSourceEnum(str, Enum):
    builtin = "builtin"
    user_created = "user_created"
    third_party_api = "third_party_api"
    experience_import = "experience_import"
    marketplace_download = "marketplace_download"
    marketplace_fork = "marketplace_fork"


# ── 基础节点 ──────────────────────────────────────────────────────────────────


class PromptNodeSchema(BaseModel):
    id: str
    prompt: str
    input_mapping: dict[str, str] = {}


# ── Skill 核心模型 ─────────────────────────────────────────────────────────────


class SkillSchema(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    description: str
    tags: list[str]
    prompt_chain: list[PromptNodeSchema]
    required_components: list[str] = []
    version: str = "1.0.0"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    type: str  # "builtin" | "custom"
    source: SkillSourceEnum
    created_by: Optional[str] = None
    schema_version: str = "1.0"  # Skill JSON Schema 版本号


class MarketplaceSkillSchema(SkillSchema):
    download_count: int = 0
    submitter_id: Optional[str] = None
    submitted_at: Optional[datetime] = None
    original_marketplace_id: Optional[str] = None  # 下载时记录云端原始 ID
    downloaded_at: Optional[datetime] = None


# ── 草稿与对话会话 ─────────────────────────────────────────────────────────────


class SkillDraftSchema(BaseModel):
    session_id: Optional[str] = None
    name: Optional[str] = None
    description: Optional[str] = None
    tags: list[str] = []
    steps: list[PromptNodeSchema] = []
    required_components: list[str] = []
    is_draft: bool = True
    source_text_length: Optional[int] = None


class DialogSession(BaseModel):
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    current_step: int = 0
    collected_data: dict[str, Any] = {}
    draft: SkillDraftSchema = Field(default_factory=SkillDraftSchema)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    is_ai_available: bool = True


class DialogTurn(BaseModel):
    session_id: str
    question: str  # 下一个问题（用户友好表述，无技术术语）
    draft_preview: Optional[SkillDraftSchema] = None  # 收集到足够信息后展示
    is_complete: bool = False  # True 时展示确认界面


# ── 日志与请求模型 ─────────────────────────────────────────────────────────────


class ParseLog(BaseModel):
    model_name: str
    duration_ms: float
    input_char_count: int
    output_node_count: int
    success: bool
    error: Optional[str] = None


class SkillSubmitRequest(BaseModel):
    name: str
    description: str
    tags: list[str]
    prompt_chain: list[PromptNodeSchema]
    required_components: list[str] = []
    version: str = "1.0.0"


# ── 分页与导入结果 ─────────────────────────────────────────────────────────────


class PaginatedSkillList(BaseModel):
    skills: list[MarketplaceSkillSchema]
    total: int
    page: int
    page_size: int


class SkillImportResult(BaseModel):
    success: bool
    skill: Optional[SkillSchema] = None
    missing_components: list[str] = []  # 缺失的 Component ID 列表
    errors: list[str] = []
