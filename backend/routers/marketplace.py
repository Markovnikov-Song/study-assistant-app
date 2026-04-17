# backend/routers/marketplace.py
"""
Skill 市场 API 路由。
挂载在 /api/marketplace

端点：
  GET  /api/marketplace/skills              — 浏览 Skill 列表（支持过滤/分页）
  GET  /api/marketplace/skills/{id}         — 获取单个 Skill 完整定义
  POST /api/marketplace/skills              — 第三方提交 Skill（需认证）
  POST /api/marketplace/skills/{id}/download — 下载 Skill 到本地库
"""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, field_validator

from deps import get_current_user
from skill_ecosystem.marketplace_service import get_marketplace_service
from skill_ecosystem.models import SkillSubmitRequest

router = APIRouter()


# ── 请求/响应模型 ──────────────────────────────────────────────────────────────


class DownloadRequest(BaseModel):
    user_id: Optional[str] = None  # 可选，未提供时使用认证用户 ID


# ── 端点 ───────────────────────────────────────────────────────────────────────


@router.get("/skills")
def list_marketplace_skills(
    tag: Optional[str] = None,
    keyword: Optional[str] = None,
    source: Optional[str] = None,
    sort_by: str = "download_count",
    page: int = 1,
    page_size: int = 20,
    user=Depends(get_current_user),
):
    """
    浏览 Skill 列表，支持 tag/keyword/source/sort_by/page 过滤。
    每页最多 20 条（属性 12：只返回通过结构验证的 Skill）。
    需求 6.1、6.2、6.5。
    """
    svc = get_marketplace_service()
    return svc.list_skills(
        tag=tag,
        keyword=keyword,
        source=source,
        sort_by=sort_by,
        page=page,
        page_size=page_size,
    )


@router.get("/skills/{skill_id}")
def get_marketplace_skill(skill_id: str, user=Depends(get_current_user)):
    """
    获取单个 Skill 完整定义（含 prompt_chain）。
    需求 6.1。
    """
    svc = get_marketplace_service()
    skill = svc.get_skill(skill_id)
    if skill is None:
        raise HTTPException(404, f"Skill '{skill_id}' 不存在")
    return skill


@router.post("/skills", status_code=201)
def submit_marketplace_skill(
    body: SkillSubmitRequest,
    user=Depends(get_current_user),
):
    """
    第三方提交 Skill（需认证）。
    验证失败返回 422（由 Pydantic 自动处理）。
    需求 7.1–7.6。
    """
    # 额外验证：prompt_chain 不能为空
    if not body.prompt_chain:
        raise HTTPException(422, "prompt_chain 不能为空")

    svc = get_marketplace_service()
    submitter_id = str(user["id"])
    skill = svc.submit_skill(body, submitter_id)
    return skill


@router.post("/skills/{skill_id}/download")
def download_marketplace_skill(
    skill_id: str,
    user=Depends(get_current_user),
):
    """
    下载云端 Skill 到用户本地库。
    来源标注 marketplace_download，记录 original_marketplace_id 和 downloaded_at（属性 11）。
    需求 6.3。
    """
    svc = get_marketplace_service()
    user_id = str(user["id"])
    try:
        local_skill = svc.download_skill(skill_id, user_id)
    except KeyError:
        raise HTTPException(404, f"Skill '{skill_id}' 不存在")
    return local_skill
