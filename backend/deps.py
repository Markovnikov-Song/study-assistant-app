"""JWT 认证依赖"""
from __future__ import annotations
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import get_config

_bearer = HTTPBearer()


def create_token(user_id: int, username: str) -> str:
    cfg = get_config()
    return jwt.encode(
        {"sub": str(user_id), "username": username,
         "exp": datetime.now(timezone.utc) + timedelta(hours=cfg.JWT_EXPIRE_HOURS)},
        cfg.JWT_SECRET, algorithm="HS256",
    )


def get_current_user(creds: HTTPAuthorizationCredentials = Depends(_bearer)) -> dict:
    cfg = get_config()
    try:
        payload = jwt.decode(creds.credentials, cfg.JWT_SECRET, algorithms=["HS256"])
        return {"id": int(payload["sub"]), "username": payload["username"]}
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token 已过期")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Token 无效")


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())
