from __future__ import annotations

from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class CapabilityKind(str, Enum):
    capability_app = "capability_app"
    pattern = "pattern"
    adapter = "adapter"
    provider = "provider"
    recipe = "recipe"


class CapabilityView(BaseModel):
    route: str
    mode: str = "full"


class CapabilityPlanContract(BaseModel):
    unit: str = "task"
    unit_label: str = "项任务"
    supports_daily_quota: bool = False
    supports_review: bool = False
    default_daily_quota: int | None = None
    estimated_minutes_per_unit: float | None = None
    calendar_title_template: str = "{title}"
    completion_metrics: list[str] = Field(default_factory=list)


class CapabilityDef(BaseModel):
    id: str
    kind: CapabilityKind = CapabilityKind.capability_app
    title: str
    description: str
    category: str = "general"
    version: str = "1.0.0"
    icon: str = "auto_awesome"
    color: list[str] = Field(default_factory=list)
    action_id: str | None = None
    mini_app_route: str | None = None
    views: dict[str, CapabilityView] = Field(default_factory=dict)
    standalone: bool = False
    orchestratable: bool = True
    schedulable: bool = False
    node_types: list[str] = Field(default_factory=list)
    pattern_refs: list[str] = Field(default_factory=list)
    adapter_refs: list[str] = Field(default_factory=list)
    provider_refs: list[str] = Field(default_factory=list)
    fallback_refs: list[str] = Field(default_factory=list)
    plan_contract: CapabilityPlanContract | None = None
    tags: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


class CapabilitySummary(BaseModel):
    id: str
    kind: CapabilityKind
    title: str
    description: str
    category: str
    version: str
    icon: str
    color: list[str]
    action_id: str | None = None
    mini_app_route: str | None = None
    standalone: bool
    orchestratable: bool
    schedulable: bool
    node_types: list[str]
    pattern_refs: list[str]
    adapter_refs: list[str]
    provider_refs: list[str]
    fallback_refs: list[str]
    plan_contract: CapabilityPlanContract | None = None
    tags: list[str]

    @classmethod
    def from_def(cls, capability: CapabilityDef) -> "CapabilitySummary":
        return cls(
            id=capability.id,
            kind=capability.kind,
            title=capability.title,
            description=capability.description,
            category=capability.category,
            version=capability.version,
            icon=capability.icon,
            color=capability.color,
            action_id=capability.action_id,
            mini_app_route=capability.mini_app_route,
            standalone=capability.standalone,
            orchestratable=capability.orchestratable,
            schedulable=capability.schedulable,
            node_types=capability.node_types,
            pattern_refs=capability.pattern_refs,
            adapter_refs=capability.adapter_refs,
            provider_refs=capability.provider_refs,
            fallback_refs=capability.fallback_refs,
            plan_contract=capability.plan_contract,
            tags=capability.tags,
        )


class CapabilityListOut(BaseModel):
    capabilities: list[CapabilitySummary]
    total: int
