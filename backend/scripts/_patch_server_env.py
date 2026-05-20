#!/usr/bin/env python3
"""一次性：为服务器 .env 补充 LLM_VISION_FALLBACK_MODEL 并重启服务。"""
from __future__ import annotations

import os
import sys

import paramiko

HOST = os.getenv("SSH_DEPLOY_HOST", "47.104.165.105")
USER = os.getenv("SSH_DEPLOY_USER", "admin")
PASSWORD = os.environ.get("SSH_DEPLOY_PASSWORD", "")
ENV_PATH = "/home/admin/study-assistant-app/backend/.env"
FALLBACK = "LLM_VISION_FALLBACK_MODEL=Qwen/Qwen2.5-VL-32B-Instruct"


def main() -> int:
    if not PASSWORD:
        print("Set SSH_DEPLOY_PASSWORD", file=sys.stderr)
        return 1

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        HOST,
        username=USER,
        password=PASSWORD,
        timeout=30,
        allow_agent=False,
        look_for_keys=False,
    )

    cmds = [
        f"grep -E '^LLM_VISION|^SOLVE_OCR' {ENV_PATH} || true",
        (
            f"grep -q '^LLM_VISION_FALLBACK_MODEL=' {ENV_PATH} && "
            f"sed -i 's|^LLM_VISION_FALLBACK_MODEL=.*|{FALLBACK}|' {ENV_PATH} || "
            f"echo '{FALLBACK}' >> {ENV_PATH}"
        ),
        (
            f"grep -q '^SOLVE_OCR_TIMEOUT_SECONDS=' {ENV_PATH} && "
            f"sed -i 's|^SOLVE_OCR_TIMEOUT_SECONDS=.*|SOLVE_OCR_TIMEOUT_SECONDS=45|' {ENV_PATH} || "
            f"echo 'SOLVE_OCR_TIMEOUT_SECONDS=45' >> {ENV_PATH}"
        ),
        f"grep -E '^LLM_VISION|^SOLVE_OCR' {ENV_PATH} || true",
        "sudo systemctl restart study-assistant",
        "sleep 5 && systemctl is-active study-assistant",
        "curl -s http://127.0.0.1:8000/api/health",
        "curl -s -o /dev/null -w '%{http_code}' https://www.study-assistant.cn/api/health",
    ]
    for cmd in cmds:
        print(f">>> {cmd}")
        _, stdout, stderr = client.exec_command(cmd, get_pty=True, timeout=90)
        out = stdout.read().decode("utf-8", errors="replace").strip()
        err = stderr.read().decode("utf-8", errors="replace").strip()
        code = stdout.channel.recv_exit_status()
        if out:
            print(out)
        if err:
            print("stderr:", err[:300])
        print(f"exit {code}\n")
        if code != 0 and "grep -q" not in cmd:
            client.close()
            return code

    client.close()
    print("ENV_PATCH_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
