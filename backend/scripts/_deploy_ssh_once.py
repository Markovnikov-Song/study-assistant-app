#!/usr/bin/env python3
"""一次性 SSH 部署（密码从环境变量 SSH_DEPLOY_PASSWORD 读取，不写进仓库）。"""
from __future__ import annotations

import os
import sys

import paramiko

HOST = os.getenv("SSH_DEPLOY_HOST", "47.104.165.105")
USER = os.getenv("SSH_DEPLOY_USER", "admin")
PASSWORD = os.environ.get("SSH_DEPLOY_PASSWORD", "")
PROJECT = os.getenv("SSH_DEPLOY_PROJECT", "/home/admin/study-assistant-app")


def run() -> int:
    if not PASSWORD:
        print("Set SSH_DEPLOY_PASSWORD", file=sys.stderr)
        return 1

    cmds = [
        f"cd {PROJECT} && git fetch origin master && git reset --hard origin/master && git log -1 --oneline",
        f"cd {PROJECT}/backend && . .venv/bin/activate && pip install -r requirements.txt -q",
        "sudo systemctl restart study-assistant",
        "sleep 4 && systemctl is-active study-assistant && curl -s http://127.0.0.1:8000/api/health",
        f"grep solve_problem {PROJECT}/backend/prompts/actions/builtin.yaml | head -1",
    ]

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

    for i, cmd in enumerate(cmds, 1):
        print(f"--- step {i}: {cmd[:80]}...")
        _, stdout, stderr = client.exec_command(cmd, get_pty=True, timeout=300)
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        code = stdout.channel.recv_exit_status()
        if out.strip():
            print(out.strip())
        if err.strip():
            print("stderr:", err.strip()[:400])
        print(f"exit {code}\n")
        if code != 0:
            if i == 3:
                print("systemctl failed, trying nohup fallback...")
                fallback = (
                    f"cd {PROJECT}/backend && pkill -f 'uvicorn main:app' || true; "
                    "sleep 2; . venv/bin/activate; "
                    "nohup uvicorn main:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 & "
                    "sleep 4; curl -s http://127.0.0.1:8000/api/health"
                )
                _, stdout, stderr = client.exec_command(fallback, get_pty=True, timeout=120)
                print(stdout.read().decode("utf-8", errors="replace"))
            elif i <= 2:
                client.close()
                return code

    client.close()
    print("DEPLOY_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
