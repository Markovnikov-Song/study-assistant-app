from __future__ import annotations

import json
import re
from copy import deepcopy
from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field

from .models import MiniAppValidation


WORKFLOW_SCHEMA_VERSION = "workshop.workflow.v1"
_REF_PATTERN = re.compile(r"^\$[A-Za-z_][A-Za-z0-9_.-]*$")


class ResourceRef(BaseModel):
    type: str
    id: str | int
    subject_id: int | None = None
    origin: dict[str, Any] = Field(default_factory=dict)
    snapshot: dict[str, Any] = Field(default_factory=dict)
    permissions: dict[str, bool] = Field(default_factory=dict)


class ResourceActor(BaseModel):
    id: str
    name: str
    type: str
    ref: ResourceRef | None = None
    query: dict[str, Any] | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class WorkflowBlock(BaseModel):
    block: str
    params: dict[str, Any] = Field(default_factory=dict)
    output: str | None = None
    body: list["WorkflowBlock"] = Field(default_factory=list)
    then: list["WorkflowBlock"] = Field(default_factory=list)
    else_: list["WorkflowBlock"] = Field(default_factory=list, alias="else")
    condition: dict[str, Any] | None = None

    model_config = {"populate_by_name": True}


class WorkflowScript(BaseModel):
    id: str
    hat: dict[str, Any]
    body: list[WorkflowBlock] = Field(default_factory=list)


class WorkflowDefinition(BaseModel):
    schema_version: str = WORKFLOW_SCHEMA_VERSION
    app_id: str | None = None
    version_id: str | None = None
    actors: list[ResourceActor] = Field(default_factory=list)
    scripts: list[WorkflowScript] = Field(default_factory=list)


class WorkflowValidateIn(BaseModel):
    workflow: dict[str, Any]


class WorkflowValidateOut(BaseModel):
    validation: MiniAppValidation
    normalized: dict[str, Any] = Field(default_factory=dict)


@lru_cache(maxsize=1)
def get_workflow_registry() -> dict[str, Any]:
    """Load the Scratch-style workshop registry used by docs and backend validation."""
    registry_path = Path(__file__).resolve().parents[2] / "docs" / "manifests" / "workshop_blocks.json"
    if registry_path.exists():
        with registry_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    return _fallback_registry()


def get_workflow_blocks_registry() -> dict[str, Any]:
    registry = deepcopy(get_workflow_registry())
    registry.setdefault("runtime_schema_version", WORKFLOW_SCHEMA_VERSION)
    return registry


def list_resource_actor_types() -> dict[str, Any]:
    registry = get_workflow_registry()
    return {
        "schema_version": "workshop.resource_actors.v1",
        "resource_actor_types": deepcopy(registry.get("resource_actor_types") or []),
    }


def validate_workflow_definition(raw: dict[str, Any]) -> WorkflowValidateOut:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        workflow = WorkflowDefinition.model_validate(raw)
    except Exception as error:
        return WorkflowValidateOut(
            validation=MiniAppValidation(ok=False, errors=[f"workflow schema error: {error}"]),
            normalized={},
        )

    registry = get_workflow_registry()
    block_defs = {str(item["id"]): item for item in registry.get("blocks", []) if isinstance(item, dict) and item.get("id")}
    shape_defs = {str(item["id"]): item for item in registry.get("shapes", []) if isinstance(item, dict) and item.get("id")}
    resource_types = {
        str(item["id"]) for item in registry.get("resource_actor_types", []) if isinstance(item, dict) and item.get("id")
    }
    slot_types = {str(item["id"]): item for item in registry.get("slot_types", []) if isinstance(item, dict) and item.get("id")}

    if workflow.schema_version != WORKFLOW_SCHEMA_VERSION:
        errors.append(f"schema_version must be {WORKFLOW_SCHEMA_VERSION}")
    if not workflow.scripts:
        errors.append("workflow.scripts must contain at least one script")

    actor_ids: set[str] = set()
    for actor in workflow.actors:
        if actor.id in actor_ids:
            errors.append(f"duplicate actor id: {actor.id}")
        actor_ids.add(actor.id)
        _validate_actor(actor, resource_types, errors, warnings)

    for script in workflow.scripts:
        _validate_script(script, block_defs, shape_defs, slot_types, actor_ids, errors, warnings)

    normalized = workflow.model_dump(by_alias=True)
    return WorkflowValidateOut(
        validation=MiniAppValidation(ok=not errors, errors=errors, warnings=_dedupe(warnings)),
        normalized=normalized,
    )


def _validate_actor(
    actor: ResourceActor,
    resource_types: set[str],
    errors: list[str],
    warnings: list[str],
) -> None:
    if not actor.id.strip():
        errors.append("resource actor id cannot be empty")
    if not actor.name.strip():
        errors.append(f"resource actor {actor.id} name cannot be empty")
    if actor.type not in resource_types:
        errors.append(f"unknown resource actor type: {actor.type}")
    if actor.ref is None and actor.query is None:
        errors.append(f"resource actor {actor.id} requires ref or query")
    if actor.ref is not None and actor.ref.type not in resource_types:
        errors.append(f"resource actor {actor.id} has unknown ref type: {actor.ref.type}")
    if actor.ref is not None and not actor.ref.snapshot:
        warnings.append(f"resource actor {actor.id} uses live ref without snapshot")


def _validate_script(
    script: WorkflowScript,
    block_defs: dict[str, dict[str, Any]],
    shape_defs: dict[str, dict[str, Any]],
    slot_types: dict[str, dict[str, Any]],
    actor_ids: set[str],
    errors: list[str],
    warnings: list[str],
) -> None:
    hat_id = str(script.hat.get("block") or "")
    hat = block_defs.get(hat_id)
    if hat is None:
        errors.append(f"{script.id}.hat uses unknown block: {hat_id}")
    elif str(hat.get("shape")) != "hat":
        errors.append(f"{script.id}.hat must use a hat block")
    if not script.body:
        warnings.append(f"{script.id} has no body blocks")
    scope: set[str] = set(actor_ids)
    for index, block in enumerate(script.body):
        _validate_block(
            block,
            f"{script.id}.body[{index}]",
            block_defs,
            shape_defs,
            slot_types,
            scope,
            errors,
            warnings,
        )


def _validate_block(
    block: WorkflowBlock,
    path: str,
    block_defs: dict[str, dict[str, Any]],
    shape_defs: dict[str, dict[str, Any]],
    slot_types: dict[str, dict[str, Any]],
    scope: set[str],
    errors: list[str],
    warnings: list[str],
) -> None:
    block_def = block_defs.get(block.block)
    if block_def is None:
        errors.append(f"{path} uses unknown block: {block.block}")
        return
    shape_id = str(block_def.get("shape") or "")
    shape = shape_defs.get(shape_id)
    if shape is None:
        errors.append(f"{path} uses unknown shape: {shape_id}")
    if shape_id in {"hat", "reporter", "boolean"} and path.count(".body") + path.count(".then") + path.count(".else") > 0:
        if shape_id == "hat":
            errors.append(f"{path} cannot place hat block inside a script body")

    params_defs = block_def.get("params") if isinstance(block_def.get("params"), list) else []
    for param_def in params_defs:
        name = str(param_def.get("name") or "")
        slot = str(param_def.get("slot") or "")
        if not name or slot == "substack":
            continue
        value = _param_value(block, name)
        if value is None:
            if param_def.get("required"):
                errors.append(f"{path}.{name} is required")
            continue
        _validate_param_value(
            value,
            slot,
            f"{path}.{name}",
            param_def,
            slot_types,
            scope,
            block_defs,
            shape_defs,
            errors,
            warnings,
        )

    if block_def.get("failure_policy_required"):
        llm_config = block.params.get("llm")
        if not isinstance(llm_config, dict) or not llm_config.get("on_failure"):
            errors.append(f"{path}.llm.on_failure is required for LLM blocks")

    if block_def.get("requires_idempotency_key"):
        policy = block.params.get("policy")
        if not isinstance(policy, dict):
            errors.append(f"{path}.policy is required for writeback blocks")
        else:
            if not policy.get("idempotency_key"):
                errors.append(f"{path}.policy.idempotency_key is required")
            if policy.get("bind_version") is not True:
                errors.append(f"{path}.policy.bind_version must be true")

    if block.output:
        if not _valid_identifier(block.output):
            errors.append(f"{path}.output must be a valid variable name")
        scope.add(block.output)

    if block.condition is not None:
        _validate_expression_block(
            block.condition,
            "boolean",
            f"{path}.condition",
            block_defs,
            shape_defs,
            scope,
            errors,
            warnings,
        )

    substack_scopes = {
        "body": _substack_scope(block, scope),
        "then": set(scope),
        "else": set(scope),
    }
    for child_name, children in (("body", block.body), ("then", block.then), ("else", block.else_)):
        child_scope = substack_scopes[child_name]
        for index, child in enumerate(children):
            _validate_block(
                child,
                f"{path}.{child_name}[{index}]",
                block_defs,
                shape_defs,
                slot_types,
                child_scope,
                errors,
                warnings,
            )


def _substack_scope(block: WorkflowBlock, scope: set[str]) -> set[str]:
    child_scope = set(scope)
    if block.block == "control.for_each":
        item_name = block.params.get("item_name")
        if isinstance(item_name, str) and _valid_identifier(item_name):
            child_scope.add(item_name)
    return child_scope


def _param_value(block: WorkflowBlock, name: str) -> Any:
    if name == "condition" and block.condition is not None:
        return block.condition
    return block.params.get(name)


def _validate_param_value(
    value: Any,
    slot: str,
    path: str,
    param_def: dict[str, Any],
    slot_types: dict[str, dict[str, Any]],
    scope: set[str],
    block_defs: dict[str, dict[str, Any]],
    shape_defs: dict[str, dict[str, Any]],
    errors: list[str],
    warnings: list[str],
) -> None:
    if slot not in slot_types:
        errors.append(f"{path} uses unknown slot type: {slot}")
        return
    if slot == "number":
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            errors.append(f"{path} must be a number")
            return
        if "min" in param_def and value < param_def["min"]:
            errors.append(f"{path} must be >= {param_def['min']}")
        if "max" in param_def and value > param_def["max"]:
            errors.append(f"{path} must be <= {param_def['max']}")
    elif slot == "text":
        if not isinstance(value, str):
            errors.append(f"{path} must be text")
    elif slot == "enum":
        options = param_def.get("options") or []
        if value not in options:
            errors.append(f"{path} must be one of: {', '.join(map(str, options))}")
    elif slot == "boolean_expression":
        _validate_expression_block(value, "boolean", path, block_defs, shape_defs, scope, errors, warnings)
    elif slot == "reporter_expression":
        _validate_reporter_value(value, path, scope, block_defs, shape_defs, errors, warnings)
    elif slot == "resource_ref":
        _validate_resource_ref_value(value, path, set(param_def.get("accepts") or []), errors, warnings)
    elif slot in {"resource_query", "resource_set"}:
        if not isinstance(value, dict):
            errors.append(f"{path} must be a resource query object")
        elif not value.get("resource_types") and not value.get("type") and not value.get("subject_id"):
            warnings.append(f"{path} resource query has no narrowing filter")
    elif slot == "llm_config":
        if not isinstance(value, dict):
            errors.append(f"{path} must be an LLM config object")
        elif not value.get("model"):
            errors.append(f"{path}.model is required")
    elif slot == "write_policy":
        if not isinstance(value, dict):
            errors.append(f"{path} must be a write policy object")


def _validate_expression_block(
    value: Any,
    expected_shape: str,
    path: str,
    block_defs: dict[str, dict[str, Any]],
    shape_defs: dict[str, dict[str, Any]],
    scope: set[str],
    errors: list[str],
    warnings: list[str],
) -> None:
    if isinstance(value, str):
        _validate_reference(value, path, scope, errors)
        return
    if not isinstance(value, dict):
        errors.append(f"{path} must be a {expected_shape} expression block")
        return
    block_id = str(value.get("block") or "")
    block_def = block_defs.get(block_id)
    if block_def is None:
        errors.append(f"{path} uses unknown expression block: {block_id}")
        return
    shape_id = str(block_def.get("shape") or "")
    if shape_id != expected_shape:
        errors.append(f"{path} must use a {expected_shape} block, got {shape_id}")
    if shape_id not in shape_defs:
        errors.append(f"{path} uses unknown expression shape: {shape_id}")
    params = value.get("params") if isinstance(value.get("params"), dict) else {}
    for item in block_def.get("params") or []:
        name = str(item.get("name") or "")
        if not name or item.get("slot") == "substack":
            continue
        if item.get("required") and name not in params:
            errors.append(f"{path}.{name} is required")


def _validate_reporter_value(
    value: Any,
    path: str,
    scope: set[str],
    block_defs: dict[str, dict[str, Any]],
    shape_defs: dict[str, dict[str, Any]],
    errors: list[str],
    warnings: list[str],
) -> None:
    if isinstance(value, str):
        _validate_reference(value, path, scope, errors)
        return
    if isinstance(value, (int, float, bool)) or value is None:
        return
    if isinstance(value, dict) and value.get("block"):
        _validate_expression_block(value, "reporter", path, block_defs, shape_defs, scope, errors, warnings)
        return
    if isinstance(value, (dict, list)):
        return
    errors.append(f"{path} must be a literal, variable reference, or reporter block")


def _validate_resource_ref_value(
    value: Any,
    path: str,
    accepts: set[str],
    errors: list[str],
    warnings: list[str],
) -> None:
    if isinstance(value, str):
        return
    if not isinstance(value, dict):
        errors.append(f"{path} must be a resource ref object")
        return
    ref_type = str(value.get("type") or "")
    if accepts and ref_type and ref_type not in accepts:
        errors.append(f"{path}.type must be one of: {', '.join(sorted(accepts))}")
    if not value.get("id") and not value.get("query"):
        errors.append(f"{path} requires id or query")
    if value.get("id") and not value.get("snapshot"):
        warnings.append(f"{path} uses live resource ref without snapshot")


def _validate_reference(value: str, path: str, scope: set[str], errors: list[str]) -> None:
    if not value.startswith("$"):
        return
    if not _REF_PATTERN.match(value):
        errors.append(f"{path} has invalid reference syntax: {value}")
        return
    root = value[1:].split(".", 1)[0]
    if root not in scope and root not in {"current_subject", "run_id", "app_id", "version_id"}:
        errors.append(f"{path} references undefined value: {value}")


def _valid_identifier(value: str) -> bool:
    return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", value))


def _dedupe(items: list[str]) -> list[str]:
    seen: list[str] = []
    for item in items:
        if item not in seen:
            seen.append(item)
    return seen


def _fallback_registry() -> dict[str, Any]:
    return {
        "schema_version": "0.1.0",
        "resource_actor_types": [],
        "shapes": [
            {"id": "hat"},
            {"id": "stack"},
            {"id": "c_block"},
            {"id": "reporter"},
            {"id": "boolean"},
        ],
        "slot_types": [
            {"id": "number"},
            {"id": "text"},
            {"id": "enum"},
            {"id": "boolean_expression"},
            {"id": "reporter_expression"},
            {"id": "resource_ref"},
            {"id": "resource_query"},
            {"id": "llm_config"},
            {"id": "write_policy"},
            {"id": "substack"},
        ],
        "blocks": [{"id": "event.on_start", "shape": "hat", "category": "event"}],
    }
