#!/usr/bin/env python3
"""分片上传 Web 包（每片 4MB），适合不稳定网络。"""
from __future__ import annotations

import glob
import os
import sys
import time
import urllib.request

import paramiko

HOST = "47.104.165.105"
USER = "admin"
PASSWORD = os.environ.get("DEPLOY_SSH_PASS") or os.environ.get("SSH_DEPLOY_PASSWORD", "")
WEB_ROOT = "/var/www/study-assistant-web"
ARCHIVE = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "build", "study-assistant-web.tar.gz")
)
CHUNK_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "build", "web_chunks"))
PART_SIZE = 4 * 1024 * 1024
REMOTE_DIR = "/tmp/web_deploy_chunks"


def connect() -> paramiko.SSHClient:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username=USER, password=PASSWORD, timeout=60, allow_agent=False, look_for_keys=False)
    return c


def split_archive() -> list[str]:
    os.makedirs(CHUNK_DIR, exist_ok=True)
    for old in glob.glob(os.path.join(CHUNK_DIR, "part_*")):
        os.remove(old)
    parts: list[str] = []
    with open(ARCHIVE, "rb") as src:
        i = 0
        while True:
            data = src.read(PART_SIZE)
            if not data:
                break
            path = os.path.join(CHUNK_DIR, f"part_{i:04d}")
            with open(path, "wb") as out:
                out.write(data)
            parts.append(path)
            i += 1
    print(f"split into {len(parts)} parts")
    return parts


def upload_part(local: str, remote: str, retries: int = 8) -> None:
    for n in range(1, retries + 1):
        try:
            c = connect()
            sftp = c.open_sftp()
            sftp.put(local, remote)
            sftp.close()
            c.close()
            return
        except Exception as exc:
            print(f"  retry {n}/{retries}: {exc}")
            time.sleep(2 * n)
    raise RuntimeError(f"failed upload {local}")


def main() -> int:
    if not PASSWORD:
        print("Set DEPLOY_SSH_PASS", file=sys.stderr)
        return 1
    if not os.path.isfile(ARCHIVE):
        print("missing archive", ARCHIVE, file=sys.stderr)
        return 1

    parts = split_archive()
    c = connect()
    c.exec_command(f"rm -rf {REMOTE_DIR} && mkdir -p {REMOTE_DIR}")
    time.sleep(1)
    c.close()

    for i, local in enumerate(parts):
        remote = f"{REMOTE_DIR}/part_{i:04d}"
        size_mb = os.path.getsize(local) / 1024 / 1024
        print(f"[{i+1}/{len(parts)}] upload {size_mb:.1f}MB -> {remote}")
        upload_part(local, remote)

    print("merge on server...")
    c = connect()
    remote_tar = "/tmp/study-assistant-web.tar.gz"
    cmd = f"""set -e
cat {REMOTE_DIR}/part_* > {remote_tar}
ls -lh {remote_tar}
rm -rf {REMOTE_DIR}
sudo mkdir -p {WEB_ROOT}
sudo find {WEB_ROOT} -mindepth 1 -maxdepth 1 -exec rm -rf {{}} +
sudo tar -xzf {remote_tar} -C {WEB_ROOT}
sudo chown -R www-data:www-data {WEB_ROOT} 2>/dev/null || true
sudo chmod -R a+rX {WEB_ROOT}
rm -f {remote_tar}
sudo nginx -t && sudo systemctl reload nginx
curl -s https://www.study-assistant.cn/api/health; echo
curl -s -o /dev/null -w 'inbox:%{{http_code}}\\n' https://www.study-assistant.cn/api/ops/inbox
systemctl is-active study-assistant
"""
    _, stdout, stderr = c.exec_command(cmd, timeout=600)
    print(stdout.read().decode())
    err = stderr.read().decode()
    if err.strip():
        print("stderr:", err[:400])
    c.close()

    for url in (
        "https://www.study-assistant.cn/api/health",
        "https://www.study-assistant.cn/api/ops/inbox",
    ):
        r = urllib.request.urlopen(url, timeout=20)
        print("verify", url, r.status)
    print("WEB_DEPLOY_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
