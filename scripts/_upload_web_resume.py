#!/usr/bin/env python3
"""断点续传上传 Web 包并发布。"""
from __future__ import annotations

import os
import sys
import time
import urllib.request

import paramiko

HOST = os.getenv("SSH_DEPLOY_HOST", "47.104.165.105")
USER = os.getenv("SSH_DEPLOY_USER", "admin")
PASSWORD = os.environ.get("SSH_DEPLOY_PASSWORD") or os.environ.get("DEPLOY_SSH_PASS", "")
WEB_ROOT = "/var/www/study-assistant-web"
ARCHIVE = os.path.join(
    os.path.dirname(__file__), "..", "build", "study-assistant-web.tar.gz"
)
REMOTE = "/tmp/study-assistant-web.tar.gz"
CHUNK = 512 * 1024  # 512KB


def connect() -> paramiko.SSHClient:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username=USER, password=PASSWORD, timeout=60, allow_agent=False, look_for_keys=False)
    return c


def remote_size(sftp: paramiko.SFTPClient) -> int:
    try:
        return sftp.stat(REMOTE).st_size
    except OSError:
        return 0


def upload_resume(local: str) -> None:
    total = os.path.getsize(local)
    offset = 0
    attempt = 0
    while offset < total:
        attempt += 1
        print(f"attempt {attempt}, offset {offset}/{total} ({100*offset/total:.1f}%)")
        c = connect()
        sftp = c.open_sftp()
        try:
            existing = remote_size(sftp)
            if existing > offset:
                offset = existing
                print(f"resume from server offset {offset}")
            with open(local, "rb") as f:
                f.seek(offset)
                if offset == 0:
                    rf = sftp.file(REMOTE, "wb")
                else:
                    rf = sftp.open(REMOTE, "r+")
                    rf.seek(offset)
                while offset < total:
                    data = f.read(CHUNK)
                    if not data:
                        break
                    rf.write(data)
                    offset += len(data)
                    if offset % (5 * 1024 * 1024) < CHUNK:
                        print(f"  {offset}/{total}")
                rf.close()
            sftp.close()
            c.close()
            if offset >= total:
                print("upload complete")
                return
        except Exception as exc:
            print(f"upload error: {exc}")
            try:
                sftp.close()
            except Exception:
                pass
            try:
                c.close()
            except Exception:
                pass
            time.sleep(3)
    raise RuntimeError("upload failed")


def publish() -> None:
    c = connect()
    cmd = f"""set -e
sudo mkdir -p {WEB_ROOT}
sudo find {WEB_ROOT} -mindepth 1 -maxdepth 1 -exec rm -rf {{}} +
sudo tar -xzf {REMOTE} -C {WEB_ROOT}
sudo chown -R www-data:www-data {WEB_ROOT} 2>/dev/null || true
sudo chmod -R a+rX {WEB_ROOT}
rm -f {REMOTE}
sudo nginx -t && sudo systemctl reload nginx
curl -s https://www.study-assistant.cn/api/health; echo
curl -s -o /dev/null -w 'inbox:%{{http_code}}\\n' https://www.study-assistant.cn/api/ops/inbox
"""
    _, stdout, _ = c.exec_command(cmd, timeout=300)
    print(stdout.read().decode())
    c.close()


def main() -> int:
    if not PASSWORD:
        print("Set DEPLOY_SSH_PASS", file=sys.stderr)
        return 1
    if not os.path.isfile(ARCHIVE):
        print(f"Missing {ARCHIVE}", file=sys.stderr)
        return 1
    upload_resume(ARCHIVE)
    publish()
    for url in (
        "https://www.study-assistant.cn/api/health",
        "https://www.study-assistant.cn/api/ops/inbox",
    ):
        r = urllib.request.urlopen(url, timeout=20)
        print("OK", url, r.status)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
