"""运维收件箱权限：通过环境变量 OPS_INBOX_USERNAMES 配置。"""
from __future__ import annotations

import os

from fastapi import Depends, HTTPException

from deps import get_current_user


def require_inbox_operator(user: dict = Depends(get_current_user)) -> dict:
    raw = os.getenv("OPS_INBOX_USERNAMES", "").strip()
    if not raw:
        raise HTTPException(
            503,
            "未配置 OPS_INBOX_USERNAMES，无法在收件箱查看反馈",
        )
    allowed = {n.strip() for n in raw.split(",") if n.strip()}
    if user["username"] not in allowed:
        raise HTTPException(403, "当前账号无收件箱权限")
    return user
