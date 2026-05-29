"""Upload APK and bump APP_VERSION on server."""
import os
import sys

import paramiko

HOST = "47.104.165.105"
USER = "admin"
PROJECT = "/home/admin/study-assistant-app/backend"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def _patch_env(version: str, download_url: str, changelog: str) -> str:
    return f"""
from pathlib import Path
p = Path("{PROJECT}/.env")
lines = []
for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
    if line.startswith("APP_VERSION="):
        lines.append("APP_VERSION={version}")
    elif line.startswith("APP_DOWNLOAD_URL="):
        lines.append("APP_DOWNLOAD_URL={download_url}")
    elif line.startswith("APP_CHANGELOG="):
        lines.append("APP_CHANGELOG={changelog}")
    else:
        lines.append(line)
p.write_text("\\n".join(lines) + "\\n", encoding="utf-8")
print("env ok")
"""


def main(version: str) -> int:
    password = os.environ.get("DEPLOY_SSH_PASS", "")
    if not password:
        print("Set DEPLOY_SSH_PASS", file=sys.stderr)
        return 1

    apk_local = os.path.join(ROOT, "backend", "downloads", f"app-v{version}.apk")
    if not os.path.isfile(apk_local):
        print(f"Missing {apk_local}", file=sys.stderr)
        return 1

    download_url = f"https://www.study-assistant.cn/downloads/app-v{version}.apk"
    changelog = "系统日志与答疑渲染修复"

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=password, timeout=30)

    sftp = client.open_sftp()
    remote_apk = f"{PROJECT}/downloads/app-v{version}.apk"
    print(f"Upload {os.path.getsize(apk_local) / 1024 / 1024:.1f} MB -> {remote_apk}")
    sftp.put(apk_local, remote_apk)

    patch_path = "/tmp/patch_env.py"
    with sftp.file(patch_path, "w") as f:
        f.write(_patch_env(version, download_url, changelog))
    sftp.close()

    for cmd in [
        f"python3 {patch_path}",
        f"grep '^APP_VERSION\\|^APP_DOWNLOAD' {PROJECT}/.env",
        "sudo systemctl restart study-assistant",
        "sleep 4",
        "curl -s http://127.0.0.1:8000/api/app/version",
    ]:
        _, stdout, stderr = client.exec_command(cmd)
        out = stdout.read().decode()
        err = stderr.read().decode()
        if out.strip():
            print(out.strip())
        if err.strip():
            print("stderr:", err.strip()[:300])

    client.close()
    return 0


if __name__ == "__main__":
    ver = sys.argv[1] if len(sys.argv) > 1 else "1.2.10"
    raise SystemExit(main(ver))
