from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from capabilities.draft_store import list_user_drafts, save_user_draft
from capabilities.models import (
    CapabilityDef,
    CapabilityKind,
    CapabilityListOut,
    CapabilitySummary,
)
from capabilities.registry import get_registry
from deps import get_current_user

router = APIRouter()


def _parse_bool(value: Optional[str]) -> bool | None:
    if value is None:
        return None
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "y"}:
        return True
    if normalized in {"0", "false", "no", "n"}:
        return False
    raise HTTPException(400, f"Invalid boolean query value: {value}")


class ComposeDraftIn(BaseModel):
    title: str
    description: str | None = None
    pattern_id: str
    adapter_id: str
    route_hint: str | None = None
    save: bool = True


class ComposeDraftOut(BaseModel):
    draft: CapabilityDef
    notes: list[str] = []


@router.get("", response_model=CapabilityListOut)
def list_capabilities(
    standalone: Optional[str] = None,
    orchestratable: Optional[str] = None,
    schedulable: Optional[str] = None,
    category: Optional[str] = None,
    kind: Optional[str] = None,
    user=Depends(get_current_user),
):
    kind_enum: CapabilityKind | None = None
    if kind:
        try:
            kind_enum = CapabilityKind(kind)
        except ValueError:
            allowed = ", ".join(item.value for item in CapabilityKind)
            raise HTTPException(400, f"Invalid capability kind: {kind}. Allowed: {allowed}")

    standalone_value = _parse_bool(standalone)
    orchestratable_value = _parse_bool(orchestratable)
    schedulable_value = _parse_bool(schedulable)

    registry = get_registry()
    capabilities = registry.summaries(
        standalone=standalone_value,
        orchestratable=orchestratable_value,
        schedulable=schedulable_value,
        category=category,
        kind=kind_enum,
    )
    for draft in list_user_drafts(user["id"]):
        if standalone_value is not None and draft.standalone != standalone_value:
            continue
        if orchestratable_value is not None and draft.orchestratable != orchestratable_value:
            continue
        if schedulable_value is not None and draft.schedulable != schedulable_value:
            continue
        if category and draft.category != category:
            continue
        if kind_enum is not None and draft.kind != kind_enum:
            continue
        capabilities.append(CapabilitySummary.from_def(draft))
    return CapabilityListOut(capabilities=capabilities, total=len(capabilities))


@router.get("/{capability_id}", response_model=CapabilityDef)
def get_capability(capability_id: str, user=Depends(get_current_user)):
    capability = get_registry().get(capability_id)
    if capability is None:
        for draft in list_user_drafts(user["id"]):
            if draft.id == capability_id:
                return draft
        raise HTTPException(404, f"Capability '{capability_id}' not found")
    return capability


@router.post("/compose-draft", response_model=ComposeDraftOut)
def compose_capability_draft(body: ComposeDraftIn, user=Depends(get_current_user)):
    """Compose a capability-app draft from a Pattern and an Adapter."""
    registry = get_registry()
    pattern = registry.get(body.pattern_id)
    adapter = registry.get(body.adapter_id)
    if pattern is None:
        raise HTTPException(404, f"Pattern '{body.pattern_id}' not found")
    if adapter is None:
        raise HTTPException(404, f"Adapter '{body.adapter_id}' not found")
    if pattern.kind != CapabilityKind.pattern:
        raise HTTPException(400, f"'{body.pattern_id}' is not a Pattern")
    if adapter.kind != CapabilityKind.adapter:
        raise HTTPException(400, f"'{body.adapter_id}' is not an Adapter")

    safe_title = body.title.strip()
    if not safe_title:
        raise HTTPException(400, "title cannot be empty")
    slug = "".join(ch.lower() if ch.isalnum() else "." for ch in safe_title).strip(".")
    while ".." in slug:
        slug = slug.replace("..", ".")
    if not slug:
        slug = f"custom.{user['id']}"

    draft = CapabilityDef(
        id=f"draft.{slug}",
        kind=CapabilityKind.capability_app,
        title=safe_title,
        description=body.description
        or f"由「{pattern.title}」和「{adapter.title}」组合生成的能力应用草稿。",
        category="custom",
        version="0.1.0",
        icon="precision_manufacturing",
        color=["#2563EB", "#10B981"],
        mini_app_route=body.route_hint or "/workshop",
        standalone=True,
        orchestratable=True,
        schedulable=pattern.schedulable,
        node_types=sorted(set(pattern.node_types + adapter.node_types)),
        pattern_refs=[pattern.id],
        adapter_refs=[adapter.id],
        provider_refs=sorted(set(pattern.provider_refs + adapter.provider_refs)),
        fallback_refs=sorted(set(pattern.fallback_refs + adapter.fallback_refs)),
        tags=sorted(set(["草稿", "工坊", *pattern.tags[:2], *adapter.tags[:2]])),
        metadata={
            "created_by": str(user["id"]),
            "source": "workshop_composer",
            "pattern_title": pattern.title,
            "adapter_title": adapter.title,
        },
    )
    if body.save:
        draft = save_user_draft(user["id"], draft)

    return ComposeDraftOut(
        draft=draft,
        notes=[
            "草稿已保存到你的本地能力库。",
            "下一步可为它绑定独立界面、输入输出 schema 和安装发布流程。",
        ],
    )
