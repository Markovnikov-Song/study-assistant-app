# backend/skill_ecosystem/skill_io.py
"""
Skill JSON 导入导出工具。
  - export_skill(skill_id) -> str：序列化为 JSON 字符串（含 schema_version）
  - import_skill(json_str, registered_components) -> SkillImportResult：
      反序列化并验证，检测缺失 Component
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime

from skill_ecosystem.models import (
    PromptNodeSchema,
    SkillImportResult,
    SkillSchema,
    SkillSourceEnum,
)


def export_skill(skill_id: str) -> str:
    """
    从内置 Skill 列表序列化为 JSON 字符串（含 schema_version）。
    若 skill_id 不存在则抛出 KeyError。
    需求 8.1、8.2。
    """
    # 延迟导入避免循环依赖
    from routers.agent import _SKILL_INDEX

    raw = _SKILL_INDEX.get(skill_id)
    if raw is None:
        raise KeyError(f"Skill '{skill_id}' 不存在")

    # 将内置 dict 格式转换为 SkillSchema
    skill = _dict_to_skill_schema(raw)
    return skill.model_dump_json(indent=2)


def import_skill(
    json_str: str,
    registered_components: list[str],
) -> SkillImportResult:
    """
    反序列化 JSON 字符串并验证，检测缺失 Component。
    格式不合法时返回错误不保存。
    需求 8.3、8.4、8.5。
    """
    # 解析 JSON
    try:
        data = json.loads(json_str)
    except (json.JSONDecodeError, ValueError) as exc:
        return SkillImportResult(
            success=False,
            errors=[f"JSON 格式错误：{exc}"],
        )

    # 验证必填字段
    errors: list[str] = []
    required_fields = ["name", "description", "tags", "prompt_chain", "type", "source"]
    for field in required_fields:
        if field not in data or data[field] is None:
            errors.append(f"缺少必填字段：{field}")

    if errors:
        return SkillImportResult(success=False, errors=errors)

    # 验证 prompt_chain 非空
    prompt_chain_raw = data.get("prompt_chain") or []
    if not prompt_chain_raw:
        errors.append("prompt_chain 不能为空")
        return SkillImportResult(success=False, errors=errors)

    # 构建 PromptNodeSchema 列表
    try:
        prompt_chain = [
            PromptNodeSchema(
                id=node.get("id", f"node_{i}"),
                prompt=node["prompt"],
                input_mapping=node.get("input_mapping") or {},
            )
            for i, node in enumerate(prompt_chain_raw)
        ]
    except (KeyError, TypeError) as exc:
        return SkillImportResult(
            success=False,
            errors=[f"prompt_chain 格式错误：{exc}"],
        )

    # 验证 source 枚举
    try:
        source = SkillSourceEnum(data["source"])
    except ValueError:
        return SkillImportResult(
            success=False,
            errors=[f"source 值无效：{data['source']}，可选值：{[e.value for e in SkillSourceEnum]}"],
        )

    # 检测缺失 Component（属性 14）
    required_components: list[str] = list(data.get("required_components") or [])
    missing_components: list[str] = [
        comp for comp in required_components
        if comp not in registered_components
    ]

    # 构建 SkillSchema（导入时重新分配 id）
    skill = SkillSchema(
        id=str(uuid.uuid4()),
        name=str(data["name"]),
        description=str(data["description"]),
        tags=list(data.get("tags") or []),
        prompt_chain=prompt_chain,
        required_components=required_components,
        version=str(data.get("version") or "1.0.0"),
        created_at=_parse_datetime(data.get("created_at")),
        type=str(data.get("type") or "custom"),
        source=source,
        created_by=data.get("created_by"),
        schema_version=str(data.get("schema_version") or "1.0"),
    )

    return SkillImportResult(
        success=True,
        skill=skill,
        missing_components=missing_components,
        errors=[],
    )


# ── 内部工具函数 ───────────────────────────────────────────────────────────────


def _dict_to_skill_schema(raw: dict) -> SkillSchema:
    """将内置 Skill dict（camelCase）转换为 SkillSchema（snake_case）。"""
    prompt_chain = [
        PromptNodeSchema(
            id=node["id"],
            prompt=node["prompt"],
            input_mapping=node.get("inputMapping") or node.get("input_mapping") or {},
        )
        for node in (raw.get("promptChain") or raw.get("prompt_chain") or [])
    ]
    return SkillSchema(
        id=raw["id"],
        name=raw["name"],
        description=raw["description"],
        tags=list(raw.get("tags") or []),
        prompt_chain=prompt_chain,
        required_components=list(raw.get("requiredComponents") or raw.get("required_components") or []),
        version=str(raw.get("version") or "1.0.0"),
        created_at=datetime.utcnow(),
        type=str(raw.get("type") or "builtin"),
        source=SkillSourceEnum.builtin,
        created_by=raw.get("createdBy") or raw.get("created_by"),
        schema_version="1.0",
    )


def _parse_datetime(value: object) -> datetime:
    """安全解析 datetime 字段，失败时返回当前时间。"""
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            pass
    return datetime.utcnow()
