from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from deps import create_token, hash_password, verify_password
from database import User, get_session

router = APIRouter()

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
    return AuthOut(access_token=create_token(uid, uname), user_id=uid, username=uname)

@router.post("/login", response_model=AuthOut)
def login(body: LoginIn):
    with get_session() as db:
        user = db.query(User).filter_by(username=body.username).first()
        if not user or not verify_password(body.password, user.password_hash):
            raise HTTPException(401, "用户名或密码错误")
        uid, uname = user.id, user.username
    return AuthOut(access_token=create_token(uid, uname), user_id=uid, username=uname)

@router.post("/logout")
def logout():
    return {"detail": "已登出"}  # JWT 无状态，客户端丢弃 token 即可
