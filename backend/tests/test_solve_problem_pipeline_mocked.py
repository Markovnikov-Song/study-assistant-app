"""
解题业务链路测试（mock OCR/LLM/DB，验证能产出 SSE 解题流）。

这不是「拍照搜题产品质量」测试，而是验证：
  dispatch(有图) → solve_problem → OCR → LLM 流式 → [DONE]
在依赖正常时代码路径是通的。
"""
from __future__ import annotations

import json
import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from deps import get_current_user
from routers import cas as cas_router

_TINY_PNG_B64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z4BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)
_FAKE_OCR = "已知 $f(x)=x^2+1$，求 $f(2)$。"
_FAKE_LLM_TOKENS = ["考点", "：二次函数。", "\n", "答案", "：", "5"]


def _parse_sse_events(body: str) -> list[dict]:
    events = []
    for line in body.split("\n"):
        line = line.strip()
        if line.startswith("data: "):
            events.append(json.loads(line[6:]))
    return events


@pytest.fixture
def solve_client(monkeypatch):
    """走真实 DispatchPipeline + solve_problem_executor，但 mock 外部依赖。"""
    import cas.executors.solve_problem  # noqa: F401 — 注册 Executor

    import backend_config

    # 最小配置，避免 get_config 失败
    if backend_config._config is None:
        monkeypatch.setenv("DATABASE_URL", "postgresql://u:p@localhost/db")
        monkeypatch.setenv("LLM_API_KEY", "sk-test")
        monkeypatch.setenv("LLM_BASE_URL", "https://example.com/v1")
        monkeypatch.setenv("LLM_CHAT_MODEL", "test-model")
        monkeypatch.setenv("LLM_EMBEDDING_MODEL", "test-embed")
        monkeypatch.setenv("JWT_SECRET", "x" * 32)
        backend_config._config = None

    mock_ocr = MagicMock()
    mock_ocr.extract_text_from_base64_list = AsyncMock(return_value=_FAKE_OCR)

    async def fake_stream(*_args, **_kwargs):
        for t in _FAKE_LLM_TOKENS:
            yield t

    mock_llm = MagicMock()
    mock_llm.stream_chat = fake_stream

    with (
        patch("services.ocr_service.OCRService", return_value=mock_ocr),
        patch("services.llm_service.LLMService", return_value=mock_llm),
        patch(
            "cas.executors.solve_problem._create_solve_session",
            new=AsyncMock(return_value=42),
        ),
        patch(
            "cas.executors.solve_problem._persist_conversation",
            new=AsyncMock(),
        ),
    ):
        app = FastAPI()
        app.include_router(cas_router.router, prefix="/api/cas")
        app.dependency_overrides[get_current_user] = lambda: {
            "id": 1,
            "username": "test",
        }
        yield TestClient(app)


def test_photo_solve_produces_streaming_answer(solve_client):
    """业务语义：有图 → SSE 里应有 OCR 后的解题正文，并以 [DONE] 结束。"""
    r = solve_client.post(
        "/api/cas/dispatch",
        json={"text": "", "images": [_TINY_PNG_B64]},
    )
    assert r.status_code == 200, r.text[:300]
    assert "text/event-stream" in r.headers.get("content-type", "")

    events = _parse_sse_events(r.text)
    assert events, "SSE 应至少有一条事件"

    contents = [e.get("content", "") for e in events if e.get("content") not in ("[DONE]", "[ERROR]", "[CHART]")]
    full_answer = "".join(contents)
    assert "考点" in full_answer or "答案" in full_answer, f"应有解题正文，实际: {full_answer!r}"

    done = [e for e in events if e.get("content") == "[DONE]"]
    assert done, "应以 [DONE] 结束"
    assert done[-1].get("session_id") == 42

    errors = [e for e in events if e.get("content") == "[ERROR]"]
    assert not errors, f"不应出现 [ERROR]: {errors}"
