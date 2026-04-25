from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from deps import create_token, hash_password, verify_password, get_current_user
from database import User, Notebook, get_session

router = APIRouter()

SYSTEM_NOTEBOOKS = ["好题本", "错题本", "笔记", "通用"]


def _init_user_notebooks(user_id: int, db: Session):
    """在已有 session 中插入系统预设本，不自行 commit（由调用方统一提交）。"""
    for i, name in enumerate(SYSTEM_NOTEBOOKS):
        db.add(Notebook(
            user_id=user_id,
            name=name,
            is_system=1,
            sort_order=i,
        ))

class RegisterIn(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=6)

class LoginIn(BaseModel):
    username: str
    password: str

class AuthOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    username: str

@router.post("/register", response_model=AuthOut, status_code=201)
def register(body: RegisterIn):
    with get_session() as db:
        if db.query(User).filter_by(username=body.username).first():
            raise HTTPException(400, "用户名已被占用")
        user = User(username=body.username, password_hash=hash_password(body.password))
        db.add(user)
        db.flush()
        uid, uname = user.id, user.username
        _init_user_notebooks(uid, db)
    return AuthOut(access_token=create_token(uid, uname), user_id=uid, username=uname)

@router.post("/login", response_model=AuthOut)
def login(body: LoginIn):
    with get_session() as db:
        user = db.query(User).filter_by(username=body.username).first()
        if not user or not verify_password(body.password, user.password_hash):
            # 使用统一错误消息，防止用户名枚举攻击
            raise HTTPException(401, "用户名或密码不正确")
        uid, uname = user.id, user.username
        # 补插系统预设本（兼容旧账号）
        existing = db.query(Notebook).filter_by(user_id=uid, is_system=1).count()
        if existing == 0:
            _init_user_notebooks(uid, db)
    return AuthOut(access_token=create_token(uid, uname), user_id=uid, username=uname)

@router.post("/logout")
def logout(current_user: dict = Depends(get_current_user)):
    return {"detail": "已登出"}  # JWT 无状态，客户端丢弃 token 即可
