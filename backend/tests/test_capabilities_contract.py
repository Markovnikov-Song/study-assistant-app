from __future__ import annotations

import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import create_app
from deps import create_token


def _auth_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {create_token(1, 'test')}"}


def test_capabilities_list_contract():
    client = TestClient(create_app())

    response = client.get("/api/capabilities?standalone=true", headers=_auth_headers())

    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    first = data["capabilities"][0]
    assert {
        "id",
        "kind",
        "title",
        "description",
        "category",
        "version",
        "icon",
        "color",
        "action_id",
        "mini_app_route",
        "standalone",
        "orchestratable",
        "schedulable",
        "node_types",
        "pattern_refs",
        "adapter_refs",
        "provider_refs",
        "fallback_refs",
        "plan_contract",
        "tags",
    } == set(first)


def test_capabilities_include_quiz_generate():
    client = TestClient(create_app())

    response = client.get("/api/capabilities/quiz.generate", headers=_auth_headers())

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "quiz.generate"
    assert data["standalone"] is True
    assert data["orchestratable"] is True
    assert data["mini_app_route"] == "/toolkit/quiz"
    assert data["plan_contract"]["supports_daily_quota"] is True
    assert "attempted_count" in data["plan_contract"]["completion_metrics"]


def test_compose_capability_draft_from_pattern_and_adapter(tmp_path, monkeypatch):
    from capabilities import draft_store

    monkeypatch.setattr(draft_store, "_STORE_PATH", tmp_path / "drafts.json")
    client = TestClient(create_app())

    response = client.post(
        "/api/capabilities/compose-draft",
        headers=_auth_headers(),
        json={
            "title": "百词斩式背政治概念",
            "pattern_id": "pattern.recognition_choice",
            "adapter_id": "adapter.political_concept",
        },
    )

    assert response.status_code == 200
    data = response.json()
    draft = data["draft"]
    assert draft["kind"] == "capability_app"
    assert draft["title"] == "百词斩式背政治概念"
    assert draft["pattern_refs"] == ["pattern.recognition_choice"]
    assert draft["adapter_refs"] == ["adapter.political_concept"]
    assert draft["standalone"] is True
    assert draft["orchestratable"] is True

    list_response = client.get("/api/capabilities?category=custom", headers=_auth_headers())
    assert list_response.status_code == 200
    listed = list_response.json()["capabilities"]
    assert any(item["id"] == draft["id"] for item in listed)
