from __future__ import annotations

from copy import deepcopy
import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from deps import get_current_user
from main import create_app
from mini_apps.workflow import (
    get_workflow_blocks_registry,
    list_resource_actor_types,
    patch_workflow_definition,
    validate_workflow_definition,
)


def test_workshop_registry_exposes_scratch_like_blocks_and_slots():
    registry = get_workflow_blocks_registry()
    block_ids = {block["id"] for block in registry["blocks"]}
    shape_ids = {shape["id"] for shape in registry["shapes"]}
    slot_ids = {slot["id"] for slot in registry["slot_types"]}

    assert {"hat", "stack", "c_block", "reporter", "boolean"} <= shape_ids
    assert {"resource_ref", "resource_query", "llm_config", "write_policy"} <= slot_ids
    assert {
        "event.on_start",
        "resource.query",
        "llm.generate_quiz",
        "interaction.show_question",
        "writeback.write_mistake",
    } <= block_ids


def test_resource_actor_types_cover_learning_materials():
    types = {
        item["id"]
        for item in list_resource_actor_types()["resource_actor_types"]
    }

    assert {
        "library.document",
        "library.chunk",
        "mindmap.session",
        "mindmap.node",
        "lecture",
        "note",
        "mistake",
        "review_card",
        "generated_artifact",
    } <= types


def test_example_workflow_validates_with_resource_actors():
    registry = get_workflow_blocks_registry()
    workflow = deepcopy(registry["example_workflow"])

    result = validate_workflow_definition(workflow)

    assert result.validation.ok, result.validation.errors
    assert result.normalized["schema_version"] == "workshop.workflow.v1"
    assert result.normalized["actors"][0]["type"] == "subject"


def test_workflow_validator_rejects_llm_block_without_failure_policy():
    registry = get_workflow_blocks_registry()
    workflow = deepcopy(registry["example_workflow"])
    workflow["scripts"][0]["body"][1]["params"]["llm"].pop("on_failure")

    result = validate_workflow_definition(workflow)

    assert not result.validation.ok
    assert any("llm.on_failure" in error for error in result.validation.errors)


def test_workflow_validator_rejects_unknown_block_and_resource_actor():
    registry = get_workflow_blocks_registry()
    workflow = deepcopy(registry["example_workflow"])
    workflow["actors"][0]["type"] = "unknown.resource"
    workflow["scripts"][0]["body"][0]["block"] = "resource.does_not_exist"

    result = validate_workflow_definition(workflow)

    assert not result.validation.ok
    assert any("unknown resource actor type" in error for error in result.validation.errors)
    assert any("unknown block" in error for error in result.validation.errors)


def test_workflow_validator_reports_slot_specific_errors():
    registry = get_workflow_blocks_registry()
    workflow = deepcopy(registry["example_workflow"])
    quiz_params = workflow["scripts"][0]["body"][1]["params"]
    quiz_params["count"] = 0
    quiz_params["question_type"] = "essay"
    quiz_params["llm"]["model"] = ""
    workflow["scripts"][0]["body"][0]["params"]["query"] = "all materials"

    result = validate_workflow_definition(workflow)

    assert not result.validation.ok
    errors = "\n".join(result.validation.errors)
    assert "count must be >= 1" in errors
    assert "question_type must be one of" in errors
    assert "llm.model is required" in errors
    assert "query must be a resource query object" in errors


def test_workflow_registry_and_validate_routes():
    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: {"id": 1, "username": "test"}
    client = TestClient(app)

    registry_response = client.get("/api/mini-apps/workflow/registry")
    assert registry_response.status_code == 200
    registry = registry_response.json()
    assert registry["runtime_schema_version"] == "workshop.workflow.v1"
    assert any(block["id"] == "resource.query" for block in registry["blocks"])

    validate_response = client.post(
        "/api/mini-apps/workflow/validate",
        json={"workflow": registry["example_workflow"]},
    )
    assert validate_response.status_code == 200
    assert validate_response.json()["validation"]["ok"] is True

    patch_response = client.post(
        "/api/mini-apps/workflow/patch",
        json={
            "workflow": registry["example_workflow"],
            "instruction": "题量减半，改成选择题，资料最多 5 条",
        },
    )
    assert patch_response.status_code == 200
    patched = patch_response.json()
    assert patched["validation"]["ok"] is True
    assert patched["patch"]


def test_workflow_patch_creates_auditable_semantic_ops():
    registry = get_workflow_blocks_registry()
    workflow = deepcopy(registry["example_workflow"])

    result = patch_workflow_definition(
        workflow,
        "题量减半，改成选择题，资料最多 5 条",
    )

    assert result.validation.ok, result.validation.errors
    ops = {(item["op"], item["param"]) for item in result.patch}
    assert ("set_param", "count") in ops
    assert ("set_param", "question_type") in ops
    assert ("set_nested_param", "query.limit") in ops
    body = result.workflow["scripts"][0]["body"]
    assert body[0]["params"]["query"]["limit"] == 5
    assert body[1]["params"]["count"] == 5
    assert body[1]["params"]["question_type"] == "choice"
