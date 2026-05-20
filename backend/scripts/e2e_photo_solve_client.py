#!/usr/bin/env python3
"""
模拟 Flutter 答疑室拍照解题的端到端客户端（与 SolveSSEClient + chat_page 一致）。

用法（先在本机启动后端）：
  cd backend
  python -m uvicorn main:app --port 8000
  python scripts/e2e_photo_solve_client.py

可选环境变量：
  API_BASE=http://127.0.0.1:8000
  E2E_USERNAME / E2E_PASSWORD — 登录账号；不存在则自动注册
"""
from __future__ import annotations

import json
import os
import sys
import uuid
from pathlib import Path

import httpx

# 保证能 import backend 包
_BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_BACKEND_DIR))


def _load_env_file() -> None:
    """加载 backend/.env（兼容 BOM；不依赖 python-dotenv 是否已装）。"""
    env_path = _BACKEND_DIR / ".env"
    if not env_path.is_file():
        return
    for line in env_path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


_load_env_file()

def _default_test_image_b64() -> str:
    """生成带题目的测试图（模拟拍照搜题），失败则用最小 PNG。"""
    try:
        import base64
        import io

        from PIL import Image, ImageDraw, ImageFont

        img = Image.new("RGB", (480, 160), color=(255, 255, 255))
        draw = ImageDraw.Draw(img)
        try:
            font = ImageFont.truetype("arial.ttf", 36)
        except OSError:
            font = ImageFont.load_default()
        draw.text((24, 56), "求解: x^2 + 2x + 1 = 0", fill=(0, 0, 0), font=font)
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        return base64.b64encode(buf.getvalue()).decode("ascii")
    except Exception:
        return (
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z4BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
        )

API_BASE = os.getenv("API_BASE", "http://127.0.0.1:8000").rstrip("/")
USERNAME = os.getenv("E2E_USERNAME", f"e2e_{uuid.uuid4().hex[:8]}")
PASSWORD = os.getenv("E2E_PASSWORD", "e2e_test_pass_123456")


def _login_or_register(client: httpx.Client) -> str:
    body = {"username": USERNAME, "password": PASSWORD}
    r = client.post(f"{API_BASE}/api/auth/login", json=body, timeout=30)
    if r.status_code == 200:
        data = r.json()
        print(f"[OK] 登录成功 user={data.get('username')} id={data.get('user_id')}")
        return data["access_token"]
    if r.status_code == 401:
        r = client.post(f"{API_BASE}/api/auth/register", json=body, timeout=30)
        if r.status_code == 201:
            data = r.json()
            print(f"[OK] 注册成功 user={data.get('username')} id={data.get('user_id')}")
            return data["access_token"]
    r.raise_for_status()
    raise RuntimeError("无法登录或注册")


def _parse_sse_line(line: str) -> dict | None:
    line = line.strip()
    if not line.startswith("data: "):
        return None
    raw = line[6:]
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"content": raw}


def _simulate_flutter_photo_solve(token: str, image_b64: str) -> int:
    """与 chat_page._submitWithImages + SolveSSEClient 相同请求。"""
    payload = {
        "text": "",
        "session_id": None,
        "images": [image_b64],
        "supplement_text": "",
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "text/event-stream",
        "Content-Type": "application/json",
    }
    url = f"{API_BASE}/api/cas/dispatch"

    print(f"\n→ POST {url}")
    print(f"  payload: images×{len(payload['images'])}, text=空")

    tokens: list[str] = []
    session_id = None
    errors: list[str] = None

    with httpx.Client(timeout=httpx.Timeout(30.0, read=180.0)) as client:
        with client.stream("POST", url, json=payload, headers=headers) as resp:
            ctype = resp.headers.get("content-type", "")
            print(f"← status={resp.status_code} content-type={ctype}")

            if resp.status_code != 200:
                body = resp.read().decode("utf-8", errors="replace")
                print(f"[FAIL] 非 200（Flutter 会走 ApiException）:\n{body[:800]}")
                return 1

            if "text/event-stream" not in ctype and "application/json" in ctype:
                body = resp.read().decode("utf-8", errors="replace")
                print(f"[FAIL] 收到 JSON 而非 SSE（未进入 solve_problem 流）:\n{body[:800]}")
                return 1

            buffer = ""
            for chunk in resp.iter_bytes():
                buffer += chunk.decode("utf-8", errors="replace")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    event = _parse_sse_line(line)
                    if not event:
                        continue
                    content = event.get("content", "")
                    if content == "[DONE]":
                        session_id = event.get("session_id")
                        print(f"  … [DONE] session_id={session_id}")
                    elif content == "[ERROR]":
                        errors = [event.get("error", "未知错误")]
                        print(f"  … [ERROR] {errors[0][:200]}")
                    elif content == "[CHART]":
                        print("  … [CHART] 收到图表事件")
                    elif content:
                        tokens.append(content)

    answer = "".join(tokens).strip()
    print("\n── 解题正文（前 500 字）──")
    print(answer[:500] if answer else "(空)")
    print("──")

    if errors:
        print(f"\n[FAIL] 业务失败: {errors[0]}")
        return 1
    if not answer:
        print("\n[FAIL] 流结束但无解题正文（OCR 可能未识别到文字）")
        return 1

    print(f"\n[PASS] 端到端通过：共 {len(tokens)} 个 token 片段，合计 {len(answer)} 字")
    return 0


def main() -> int:
    image_b64 = os.getenv("E2E_IMAGE_B64", _default_test_image_b64()).strip()

    print(f"API_BASE={API_BASE}")
    try:
        with httpx.Client() as client:
            h = client.get(f"{API_BASE}/api/health", timeout=10)
            h.raise_for_status()
            print(f"[OK] health {h.json()}")
    except Exception as e:
        print(f"[FAIL] 后端未启动或不可达: {e}")
        print("  请先运行: cd backend && python -m uvicorn main:app --port 8000")
        return 1

    with httpx.Client() as client:
        token = _login_or_register(client)

    return _simulate_flutter_photo_solve(token, image_b64)


if __name__ == "__main__":
    raise SystemExit(main())
