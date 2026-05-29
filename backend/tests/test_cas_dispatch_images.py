"""CAS /api/cas/dispatch 多模态（图片）请求校验测试（不依赖数据库/LLM）。"""
from __future__ import annotations

import os
import sys
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from deps import get_current_user
from routers import cas as cas_router

# 1x1 透明 PNG
_TINY_PNG_B64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z4BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


@pytest.fixture
def cas_client(monkeypatch):
    """仅挂载 cas 路由，mock pipeline，避免拉取完整应用配置。"""
    mock_pipeline = MagicMock()
    mock_pipeline.run = AsyncMock(
        return_value=JSONResponse({"success": True, "action_id": "solve_problem"})
    )
    monkeypatch.setattr(cas_router, "get_pipeline", lambda: mock_pipeline)

    app = FastAPI()
    app.include_router(cas_router.router, prefix="/api/cas")
    app.dependency_overrides[get_current_user] = lambda: {"id": 1, "username": "test"}
    return TestClient(app), mock_pipeline


def test_dispatch_rejects_empty_text_and_images(cas_client):
    client, _ = cas_client
    r = client.post(
        "/api/cas/dispatch",
        json={"text": "", "images": []},
    )
    assert r.status_code == 400
    detail = r.json()["detail"]
    assert "图片" in detail or "文字" in detail


def test_dispatch_rejects_whitespace_only_images(cas_client):
    client, _ = cas_client
    r = client.post(
        "/api/cas/dispatch",
        json={"text": "", "images": ["", "   "]},
    )
    assert r.status_code == 400


def test_dispatch_rejects_invalid_base64_image(cas_client):
    client, _ = cas_client
    r = client.post(
        "/api/cas/dispatch",
        json={"text": "", "images": ["not-a-base64-image"]},
    )
    assert r.status_code == 400
    assert "图片数据无效" in r.json()["detail"]


def test_dispatch_accepts_data_uri_image(cas_client):
    client, mock_pipeline = cas_client
    data_uri = f"data:image/png;base64,{_TINY_PNG_B64}"
    r = client.post(
        "/api/cas/dispatch",
        json={"text": "", "images": [data_uri], "supplement_text": ""},
    )
    assert r.status_code == 200, r.text

    kwargs = mock_pipeline.run.await_args.kwargs
    assert kwargs["images"] == [_TINY_PNG_B64]


def test_dispatch_accepts_image_only_without_text(cas_client):
    """有有效 Base64 图片时不应再返回 400「输入不能为空」。"""
    client, mock_pipeline = cas_client
    r = client.post(
        "/api/cas/dispatch",
        json={"text": "", "images": [_TINY_PNG_B64], "supplement_text": ""},
    )
    assert r.status_code == 200, r.text

    mock_pipeline.run.assert_awaited_once()
    kwargs = mock_pipeline.run.await_args.kwargs
    assert kwargs["images"] == [_TINY_PNG_B64]
    assert kwargs["text"] == ""
