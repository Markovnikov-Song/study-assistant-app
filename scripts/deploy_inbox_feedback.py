#!/usr/bin/env python3
"""部署反馈收件箱 + Flutter Web（密码：SSH_DEPLOY_PASSWORD 或 DEPLOY_SSH_PASS）。"""
from __future__ import annotations

import os
import subprocess
import sys
import tarfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOST = os.getenv("SSH_DEPLOY_HOST", "47.104.165.105")
USER = os.getenv("SSH_DEPLOY_USER", "admin")
PASSWORD = os.environ.get("SSH_DEPLOY_PASSWORD") or os.environ.get("DEPLOY_SSH_PASS", "")
PROJECT = os.getenv("SSH_DEPLOY_PROJECT", "/home/admin/study-assistant-app")
WEB_ROOT = os.getenv("SSH_DEPLOY_WEB_ROOT", "/var/www/study-assistant-web")
API_URL = "https://www.study-assistant.cn"
VERSION = "1.2.12"

BACKEND_UPLOADS = [
    "backend/database.py",
    "backend/app_routes.py",
    "backend/routers/ops.py",
    "backend/ops/__init__.py",
    "backend/ops/incident_store.py",
    "backend/ops/inbox_auth.py",
    "backend/ops/inbox.html",
    "backend/ops/connectivity_guardian.py",
    "backend/ops/api_manifest.py",
    "backend/migrations/019_add_client_incidents.sql",
]


def _require_paramiko():
    try:
        import paramiko  # noqa: PLC0415
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko", "-q"])
        import paramiko  # noqa: PLC0415
    return paramiko


def connect():
    paramiko = _require_paramiko()
    if not PASSWORD:
        print("请设置环境变量 SSH_DEPLOY_PASSWORD 或 DEPLOY_SSH_PASS", file=sys.stderr)
        sys.exit(1)
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
    return client


def run(client, cmd: str, timeout: int = 300) -> tuple[int, str]:
    print(f">>> {cmd[:120]}...")
    _, stdout, stderr = client.exec_command(cmd, get_pty=True, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    code = stdout.channel.recv_exit_status()
    if out.strip():
        print(out.strip()[-2000:])
    if err.strip():
        print("stderr:", err.strip()[:400])
    print(f"exit {code}\n")
    return code, out


def upload_backend(client) -> None:
    sftp = client.open_sftp()
    for rel in BACKEND_UPLOADS:
        local = ROOT / rel.replace("/", os.sep)
        if not local.is_file():
            print(f"skip missing {local}")
            continue
        remote = f"{PROJECT}/{rel.replace(chr(92), '/')}"
        remote_dir = os.path.dirname(remote)
        run(client, f"mkdir -p {remote_dir}")
        print(f"upload {rel}")
        sftp.put(str(local), remote)
    sftp.close()


def patch_env_and_db(client) -> None:
    env_cmds = f"""
cd {PROJECT}/backend
grep -q '^OPS_INBOX_USERNAMES=' .env 2>/dev/null || echo 'OPS_INBOX_USERNAMES=admin' >> .env
mkdir -p data/incidents
chmod 755 data data/incidents 2>/dev/null || true
. venv/bin/activate 2>/dev/null || . .venv/bin/activate
python3 -c "from database import init_db; init_db(); print('init_db ok')"
grep OPS_INBOX .env || true
"""
    run(client, env_cmds, timeout=120)


def restart_backend(client) -> None:
    code, _ = run(
        client,
        "sudo systemctl restart study-assistant; sleep 5; systemctl is-active study-assistant",
    )
    if code != 0:
        run(
            client,
            f"cd {PROJECT}/backend && pkill -f 'uvicorn main:app' || true; sleep 2; "
            ". venv/bin/activate; nohup uvicorn main:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 & "
            "sleep 5; curl -s http://127.0.0.1:8000/api/health",
        )


def build_web() -> Path:
    archive = ROOT / "build" / "study-assistant-web.tar.gz"
    print(">>> flutter build web...")
    subprocess.check_call(
        [
            "flutter",
            "build",
            "web",
            "--release",
            f"--dart-define=API_BASE_URL={API_URL}",
        ],
        cwd=ROOT,
    )
    web_dir = ROOT / "build" / "web"
    index = web_dir / "index.html"
    if not index.is_file():
        raise FileNotFoundError("build/web/index.html missing")
    import shutil

    shutil.copy(index, web_dir / "404.html")
    if archive.is_file():
        archive.unlink()
    with tarfile.open(archive, "w:gz") as tar:
        for p in web_dir.iterdir():
            tar.add(p, arcname=p.name)
    print(f"web archive: {archive.stat().st_size / 1024 / 1024:.1f} MB")
    return archive


def publish_web(client, archive: Path) -> None:
    sftp = client.open_sftp()
    remote_tar = "/tmp/study-assistant-web.tar.gz"
    print(">>> upload web archive...")
    sftp.put(str(archive), remote_tar)
    sftp.close()
    script = f"""
set -e
sudo mkdir -p {WEB_ROOT}
sudo find {WEB_ROOT} -mindepth 1 -maxdepth 1 -exec rm -rf {{}} +
sudo tar -xzf {remote_tar} -C {WEB_ROOT}
sudo chown -R www-data:www-data {WEB_ROOT} 2>/dev/null || true
sudo chmod -R a+rX {WEB_ROOT}
rm -f {remote_tar}
sudo nginx -t && (sudo systemctl reload nginx || sudo service nginx reload)
"""
    run(client, script, timeout=180)


def verify() -> None:
    import urllib.request

    for url in (
        f"{API_URL}/api/health",
        f"{API_URL}/api/ops/inbox",
    ):
        try:
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=20) as resp:
                body = resp.read(512).decode("utf-8", errors="replace")
                print(f"OK {url} -> {resp.status} {body[:80]}...")
        except Exception as exc:
            print(f"WARN {url}: {exc}")


def main() -> int:
    client = connect()
    try:
        print("=== [1/5] upload backend ===")
        upload_backend(client)
        print("=== [2/5] db + env ===")
        patch_env_and_db(client)
        print("=== [3/5] restart backend ===")
        restart_backend(client)
        print("=== [4/5] build & publish web ===")
        archive = build_web()
        publish_web(client, archive)
        print("=== [5/5] verify ===")
        run(client, f"curl -s -o /dev/null -w '%{{http_code}}' {API_URL}/api/ops/inbox; echo")
        verify()
        print("\nDEPLOY_OK")
        print(f"收件箱: {API_URL}/api/ops/inbox")
        print(f"网站: {API_URL}")
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
