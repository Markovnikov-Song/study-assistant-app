from __future__ import annotations

import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import create_app


def test_health_contract():
    client = TestClient(create_app())

    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_version_contract_has_expected_fields():
    client = TestClient(create_app())

    response = client.get("/api/app/version")

    assert response.status_code == 200
    data = response.json()
    assert set(data) == {"version", "min_version", "download_url", "changelog"}
    assert all(isinstance(value, str) for value in data.values())
