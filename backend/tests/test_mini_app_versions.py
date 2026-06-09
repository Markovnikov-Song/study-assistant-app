from __future__ import annotations

from copy import deepcopy
import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from deps import get_current_user
from main import create_app
import mini_apps.store as store


def test_mini_app_versions_are_snapshotted_and_runs_bind_version(tmp_path, monkeypatch):
    monkeypatch.setattr(store, "_STORE_PATH", tmp_path / "mini_apps.json")
    monkeypatch.setattr(store, "_VERSION_PATH", tmp_path / "mini_app_versions.json")
    monkeypatch.setattr(store, "_RUN_PATH", tmp_path / "mini_app_runs.json")
    monkeypatch.setattr(store, "_SESSION_PATH", tmp_path / "mini_app_interviews.json")

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: {"id": 7, "username": "test"}
    client = TestClient(app)

    create_response = client.post(
        "/api/mini-apps",
        json={
            "title": "函数导数闪卡",
            "app_type": "memory",
            "subject_id": 1,
            "documents": {"README.md": "初始版本"},
            "spec": _sample_spec(),
        },
    )

    assert create_response.status_code == 200, create_response.text
    app_record = create_response.json()["app"]
    app_id = app_record["id"]
    first_version = app_record["current_version_id"]
    assert first_version.endswith("_v1")

    versions_response = client.get(f"/api/mini-apps/{app_id}/versions")
    assert versions_response.status_code == 200, versions_response.text
    versions = versions_response.json()
    assert versions["current_version_id"] == first_version
    assert versions["total"] == 1
    assert versions["versions"][0]["snapshot"]["spec"]["app"]["title"] == "函数导数闪卡"

    first_run_response = client.post(f"/api/mini-apps/{app_id}/runs/start")
    assert first_run_response.status_code == 200, first_run_response.text
    assert first_run_response.json()["app_version_id"] == first_version
    run_id = first_run_response.json()["run_id"]
    run_response = client.get(f"/api/mini-apps/runs/{run_id}")
    assert run_response.status_code == 200
    run = run_response.json()["run"]
    assert run["app_version_id"] == first_version
    assert run["app_snapshot"]["version_id"] == first_version

    next_spec = _sample_spec()
    next_spec["scheduler"]["new_items_per_day"] = 12
    update_response = client.put(
        f"/api/mini-apps/{app_id}",
        json={"spec": next_spec},
    )
    assert update_response.status_code == 200, update_response.text
    second_version = update_response.json()["app"]["current_version_id"]
    assert second_version != first_version

    next_versions_response = client.get(f"/api/mini-apps/{app_id}/versions")
    assert next_versions_response.status_code == 200
    next_versions = next_versions_response.json()["versions"]
    assert len(next_versions) == 2
    assert next_versions[0]["id"] == second_version
    assert next_versions[0]["parent_version_id"] == first_version
    assert next_versions[0]["snapshot"]["spec"]["scheduler"]["new_items_per_day"] == 12

    second_run_response = client.post(f"/api/mini-apps/{app_id}/runs/start")
    assert second_run_response.status_code == 200
    assert second_run_response.json()["app_version_id"] == second_version


def _sample_spec() -> dict:
    return deepcopy(
        {
            "schema_version": "miniapp.v1",
            "app": {"type": "memory", "title": "函数导数闪卡", "subject_id": 1},
            "content": {
                "source_type": "manual",
                "items": [
                    {"id": "card_1", "front": "导数定义", "back": "函数变化率的极限"},
                    {"id": "card_2", "front": "导函数", "back": "导数作为自变量函数"},
                    {"id": "card_3", "front": "切线斜率", "back": "函数在该点导数值"},
                    {"id": "card_4", "front": "单调性", "back": "导数符号判断增减"},
                    {"id": "card_5", "front": "极值点", "back": "导数变号的候选点"},
                ],
            },
            "screens": ["daily_home", "card_practice", "summary"],
            "scheduler": {
                "type": "daily_fixed",
                "new_items_per_day": 10,
                "max_reviews_per_day": 30,
            },
            "assessment": {
                "mastered_threshold": 0.85,
                "wrong_before_explanation": 2,
            },
            "practice": {"sequence": ["flashcard"]},
            "runtime": {"engine": "flashcard_runtime", "safe_blocks": []},
        }
    )
