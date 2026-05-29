"""Register mini-apps router on production server."""
import os
import sys

import paramiko

HOST = "47.104.165.105"
USER = "admin"
PASSWORD = os.environ.get("DEPLOY_SSH_PASS", "")
PROJECT = "/home/admin/study-assistant-app/backend"
MAIN = f"{PROJECT}/main.py"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def main() -> int:
    if not PASSWORD:
        print("Set DEPLOY_SSH_PASS", file=sys.stderr)
        return 1

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=30)

    # Upload latest mini_apps package + router + app_routes (for reference)
    sftp = client.open_sftp()
    uploads = [
        ("backend/routers/mini_apps.py", f"{PROJECT}/routers/mini_apps.py"),
        ("backend/app_routes.py", f"{PROJECT}/app_routes.py"),
    ]
    for rel, remote in uploads:
        local = os.path.join(ROOT, rel.replace("/", os.sep))
        print(f"upload {rel}")
        sftp.put(local, remote)

    # Upload mini_apps directory
    remote_mini = f"{PROJECT}/mini_apps"
    local_mini = os.path.join(ROOT, "backend", "mini_apps")
    for name in os.listdir(local_mini):
        if name.endswith(".py"):
            sftp.put(
                os.path.join(local_mini, name),
                f"{remote_mini}/{name}",
            )
    sftp.close()

    # Patch main.py: import + include_router + create_mini_app executor
    _, stdout, _ = client.exec_command(f"cat {MAIN}")
    content = stdout.read().decode("utf-8", errors="replace")

    if "mini_apps" not in content:
        content = content.replace(
            "from routers import auth, subjects",
            "from routers import auth, subjects",
        )
        old_import = (
            "from routers import auth, subjects, sessions, chat, documents, "
            "past_exams, exam_gen, ocr, notebooks, notes, users, hints, library, "
            "agent, mcp, marketplace, council, calendar, review, feedback, quiz, "
            "api_config, token"
        )
        new_import = old_import + ", mini_apps"
        if old_import in content:
            content = content.replace(old_import, new_import)
        else:
            # fallback: append import line after router imports block
            content = content.replace(
                "from routers import cas",
                "from routers import cas\nfrom routers import mini_apps",
            )

    if 'prefix="/api/mini-apps"' not in content:
        anchor = 'app.include_router(mcp.router,        prefix="/api/mcp",        tags=["mcp"])'
        insert = (
            anchor
            + "\n"
            + 'app.include_router(mini_apps.router, prefix="/api/mini-apps", tags=["mini-apps"])'
        )
        content = content.replace(anchor, insert)

    if "create_mini_app" not in content:
        content = content.replace(
            "import cas.executors.open_course_space",
            "import cas.executors.open_course_space\n"
            "    import cas.executors.create_mini_app",
        )

    # Write patched main.py
    patch_script = f"""
python3 << 'PY'
from pathlib import Path
p = Path({MAIN!r})
text = p.read_text(encoding='utf-8')
old_import = (
    'from routers import auth, subjects, sessions, chat, documents, '
    'past_exams, exam_gen, ocr, notebooks, notes, users, hints, library, '
    'agent, mcp, marketplace, council, calendar, review, feedback, quiz, '
    'api_config, token'
)
if ', mini_apps' not in text and old_import in text:
    text = text.replace(old_import, old_import + ', mini_apps')
if 'from routers import mini_apps' not in text:
    text = text.replace('from routers import cas', 'from routers import cas\\nfrom routers import mini_apps')
anchor = 'app.include_router(mcp.router,        prefix="/api/mcp",        tags=["mcp"])'
line = 'app.include_router(mini_apps.router, prefix="/api/mini-apps", tags=["mini-apps"])'
if line not in text and anchor in text:
    text = text.replace(anchor, anchor + '\\n' + line)
if 'create_mini_app' not in text:
    text = text.replace(
        'import cas.executors.open_course_space',
        'import cas.executors.open_course_space\\n    import cas.executors.create_mini_app',
    )
p.write_text(text, encoding='utf-8')
print('patched main.py')
PY
"""
    _, stdout, stderr = client.exec_command(patch_script)
    print(stdout.read().decode())
    err = stderr.read().decode()
    if err:
        print("stderr:", err)

    _, stdout, _ = client.exec_command(
        "sudo systemctl restart study-assistant; sleep 5; "
        "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/api/mini-apps"
    )
    print("mini-apps status:", stdout.read().decode())

    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
