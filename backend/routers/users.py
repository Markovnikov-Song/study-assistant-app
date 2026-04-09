from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from database import User, get_session
from deps import get_current_user, hash_password, verify_password

router = APIRouter()


class UsernameUpdateIn(BaseModel):
    new_username: str = Field(min_length=1, max_length=64)


class PasswordUpdateIn(BaseModel):
    old_password: str
    new_password: str = Field(min_length=6)


class AvatarUpdateIn(BaseModel):
    avatar_base64: str


class UserOut(BaseModel):
    user_id: int
    username: str
    avatar_base64: Optional[str]


@router.patch("/me/username", response_model=UserOut)
def update_username(
    body: UsernameUpdateIn,
    current_user: dict = Depends(get_current_user),
):
    with get_session() as db:
        # 检查用户名唯一性
        existing = db.query(User).filter(User.username == body.new_username).first()
        if existing and existing.id != current_user["id"]:
            raise HTTPException(409, "用户名已被占用")

        user = db.query(User).filter(User.id == current_user["id"]).first()
        user.username = body.new_username
        db.flush()
        return UserOut(user_id=user.id, username=user.username, avatar_base64=user.avatar)


@router.patch("/me/password")
def update_password(
    body: PasswordUpdateIn,
    current_user: dict = Depends(get_current_user),
):
    with get_session() as db:
        user = db.query(User).filter(User.id == current_user["id"]).first()
        if not verify_password(body.old_password, user.password_hash):
            raise HTTPException(401, "当前密码错误")
        user.password_hash = hash_password(body.new_password)
    return {"detail": "密码修改成功"}


@router.post("/me/avatar", response_model=UserOut)
def update_avatar(
    body: AvatarUpdateIn,
    current_user: dict = Depends(get_current_user),
):
    with get_session() as db:
        user = db.query(User).filter(User.id == current_user["id"]).first()
        user.avatar = body.avatar_base64
        db.flush()
        return UserOut(user_id=user.id, username=user.username, avatar_base64=user.avatar)


@router.get("/me", response_model=UserOut)
def get_me(current_user: dict = Depends(get_current_user)):
    with get_session() as db:
        user = db.query(User).filter(User.id == current_user["id"]).first()
        return UserOut(user_id=user.id, username=user.username, avatar_base64=user.avatar)
