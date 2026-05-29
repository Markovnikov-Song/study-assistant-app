from __future__ import annotations

import logging
from pathlib import Path

import yaml

from .models import CapabilityDef, CapabilityKind, CapabilitySummary

logger = logging.getLogger(__name__)

_CAPABILITIES_YAML = (
    Path(__file__).parent.parent / "prompts" / "capabilities" / "builtin.yaml"
)


class CapabilityRegistry:
    """Loads and indexes capability package manifests."""

    _instance: "CapabilityRegistry | None" = None

    def __new__(cls) -> "CapabilityRegistry":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._capabilities = []
            cls._instance._index = {}
            cls._instance._loaded = False
        return cls._instance

    def _ensure_loaded(self) -> None:
        if not self._loaded:
            self._load()

    def _load(self) -> None:
        try:
            with open(_CAPABILITIES_YAML, encoding="utf-8") as f:
                data = yaml.safe_load(f) or {}
            raw_capabilities = data.get("capabilities", [])
            capabilities: list[CapabilityDef] = []
            for raw in raw_capabilities:
                try:
                    capabilities.append(CapabilityDef(**raw))
                except Exception as exc:
                    logger.warning(
                        "CapabilityRegistry: skipped invalid capability %s: %s",
                        raw.get("id", "<unknown>") if isinstance(raw, dict) else raw,
                        exc,
                    )
            self._capabilities = capabilities
            self._index = {capability.id: capability for capability in capabilities}
            self._loaded = True
            logger.info(
                "CapabilityRegistry: loaded %d capabilities from %s",
                len(capabilities),
                _CAPABILITIES_YAML,
            )
        except FileNotFoundError:
            logger.error("CapabilityRegistry: YAML file not found: %s", _CAPABILITIES_YAML)
            self._capabilities = []
            self._index = {}
            self._loaded = True
        except Exception as exc:
            logger.error("CapabilityRegistry: failed to load capabilities: %s", exc)
            self._capabilities = []
            self._index = {}
            self._loaded = True

    def reload(self) -> None:
        self._loaded = False
        self._load()

    def get(self, capability_id: str) -> CapabilityDef | None:
        self._ensure_loaded()
        return self._index.get(capability_id)

    def list(
        self,
        *,
        standalone: bool | None = None,
        orchestratable: bool | None = None,
        schedulable: bool | None = None,
        category: str | None = None,
        kind: CapabilityKind | None = None,
    ) -> list[CapabilityDef]:
        self._ensure_loaded()
        capabilities = list(self._capabilities)
        if standalone is not None:
            capabilities = [c for c in capabilities if c.standalone == standalone]
        if orchestratable is not None:
            capabilities = [c for c in capabilities if c.orchestratable == orchestratable]
        if schedulable is not None:
            capabilities = [c for c in capabilities if c.schedulable == schedulable]
        if category:
            capabilities = [c for c in capabilities if c.category == category]
        if kind is not None:
            capabilities = [c for c in capabilities if c.kind == kind]
        return capabilities

    def summaries(
        self,
        *,
        standalone: bool | None = None,
        orchestratable: bool | None = None,
        schedulable: bool | None = None,
        category: str | None = None,
        kind: CapabilityKind | None = None,
    ) -> list[CapabilitySummary]:
        return [
            CapabilitySummary.from_def(capability)
            for capability in self.list(
                standalone=standalone,
                orchestratable=orchestratable,
                schedulable=schedulable,
                category=category,
                kind=kind,
            )
        ]


_registry: CapabilityRegistry | None = None


def get_registry() -> CapabilityRegistry:
    global _registry
    if _registry is None:
        _registry = CapabilityRegistry()
    return _registry
