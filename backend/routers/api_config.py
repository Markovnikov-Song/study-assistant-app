"""
API 配置路由：用户自定义 API Key 或使用共享配置
"""
import os
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from deps import get_current_user
from database import get_session, User

router = APIRouter()


# ============================================================================
# 共享配置口令（只在后端，前端看不到）
# ============================================================================

def _get_shared_configs():
    """从环境变量读取共享配置"""
    return {
        "slylsy": {
            "type": "developer",
            "llm_base_url": os.getenv("DEV_LLM_BASE_URL", "https://api.openai.com/v1"),
            "llm_api_key": os.getenv("DEV_LLM_API_KEY", ""),
            "vision_base_url": os.getenv("DEV_VISION_BASE_URL", "https://api.openai.com/v1"),
            "vision_api_key": os.getenv("DEV_VISION_API_KEY", ""),
        },
        # 可以添加更多口令
        # "friend2024": {...},
    }


# ============================================================================
# 请求/响应模型
# ============================================================================

class VerifyPassphraseRequest(BaseModel):
    passphrase: str


class SaveCustomConfigRequest(BaseModel):
    llm_base_url: Optional[str] = None
    llm_api_key: Optional[str] = None
    vision_base_url: Optional[str] = None
    vision_api_key: Optional[str] = None


# ============================================================================
# API 路由
# ============================================================================

@router.post("/verify-shared-config")
async def verify_shared_config(
    body: VerifyPassphraseRequest,
    user=Depends(get_current_user)
):
    """
    验证口令，启用共享配置
    前端只知道验证成功/失败，看不到实际的 API Key
    """
    passphrase = body.passphrase.strip()
    shared_configs = _get_shared_configs()
    
    if passphrase not in shared_configs:
        return {"verified": False, "message": "口令错误"}
    
    config = shared_configs[passphrase]
    
    # 检查配置是否有效
    if not config["llm_api_key"]:
        return {
            "verified": False,
            "message": "共享配置未设置，请联系开发者"
        }
    
    # 保存到用户记录
    user_id = user["id"] if isinstance(user, dict) else user.id
    with get_session() as db:
        db.query(User).filter_by(id=user_id).update({
            "use_shared_config": True,
            "shared_config_type": config["type"],
            "verified_at": datetime.now(),
            # 清空自定义配置（切换到共享配置）
            "custom_llm_base_url": None,
            "custom_llm_api_key": None,
            "custom_vision_base_url": None,
            "custom_vision_api_key": None,
        })
        db.commit()
    
    return {
        "verified": True,
        "message": "验证成功，已启用共享配置"
    }


@router.post("/save-custom-config")
async def save_custom_config(
    body: SaveCustomConfigRequest,
    user=Depends(get_current_user)
):
    """
    保存用户自己的 API 配置
    """
    user_id = user["id"] if isinstance(user, dict) else user.id
    
    with get_session() as db:
        db.query(User).filter_by(id=user_id).update({
            "use_shared_config": False,  # 切换到自定义配置
            "shared_config_type": None,
            "custom_llm_base_url": body.llm_base_url,
            "custom_llm_api_key": body.llm_api_key,
            "custom_vision_base_url": body.vision_base_url,
            "custom_vision_api_key": body.vision_api_key,
        })
        db.commit()
    
    return {"success": True, "message": "配置已保存"}


@router.get("/config-status")
async def get_config_status(user=Depends(get_current_user)):
    """
    获取用户的 API 配置状态（不返回敏感信息）
    """
    user_id = user["id"] if isinstance(user, dict) else user.id
    
    with get_session() as db:
        u = db.query(User).filter_by(id=user_id).first()
        
        return {
            "use_shared_config": bool(u.use_shared_config) if u.use_shared_config is not None else False,
            "shared_config_type": u.shared_config_type or None,
            "shared_config_verified": bool(u.use_shared_config) if u.use_shared_config is not None else False,
            "has_custom_config": bool(u.custom_llm_api_key) if u.custom_llm_api_key is not None else False,
            # 不返回实际的 key
        }


@router.post("/disable-shared-config")
async def disable_shared_config(user=Depends(get_current_user)):
    """
    禁用共享配置（切换回需要自己配置）
    """
    user_id = user["id"] if isinstance(user, dict) else user.id
    
    with get_session() as db:
        db.query(User).filter_by(id=user_id).update({
            "use_shared_config": False,
            "shared_config_type": None,
        })
        db.commit()
    
    return {"success": True, "message": "已禁用共享配置"}


@router.get("/test-connection")
async def test_api_connection(user=Depends(get_current_user)):
    """
    测试当前配置的 API 连接
    """
    from services.llm_service import LLMService
    
    user_id = user["id"] if isinstance(user, dict) else user.id
    
    try:
        llm = LLMService()
        # 发送一个简单的测试请求
        response = llm.chat(
            messages=[{"role": "user", "content": "Hi"}],
            user_id=user_id,
            max_tokens=10
        )
        return {
            "success": True,
            "message": "连接成功",
            "response": response[:50]  # 只返回前50字符
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"连接失败：{str(e)}"
        }
