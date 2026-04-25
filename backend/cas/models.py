"""
CAS Pydantic 模型定义
"""
from __future__ import annotations

from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel


# ── 参数类型枚举（6 种，不可扩展）────────────────────────────────────────────

class ParamType(str, Enum):
    radio      = "radio"
    checkbox   = "checkbox"
    number     = "number"
    text       = "text"
    date       = "date"
    topic_tree = "topic_tree"


# ── 渲染类型枚举 ──────────────────────────────────────────────────────────────

class RenderType(str, Enum):
    text       = "text"
    card       = "card"
    navigate   = "navigate"
    modal      = "modal"
    param_fill = "param_fill"   # 内部类型，触发前端参数补全卡片


# ── 参数定义 ──────────────────────────────────────────────────────────────────

class ParamDef(BaseModel):
    name:           str
    type:           ParamType
    label:          str
    required:       bool = True
    default:        Optional[Any] = None
    # radio / checkbox
    options:        Optional[list[str]] = None
    dynamic_source: Optional[str] = None   # "user_subjects" 等，运行时动态填充
    # number
    min:            Optional[float] = None
    max:            Optional[float] = None
    step:           Optional[float] = None
    # text
    max_length:     int = 200
    # date
    min_date:       Optional[str] = None
    max_date:       Optional[str] = None


# ── Action 定义 ───────────────────────────────────────────────────────────────

class ActionDef(BaseModel):
    action_id:    str
    version:      str = "1.0.0"
    name:         str
    description:  str
    fallback_text: str = "操作暂时不可用，请稍后再试"
    param_schema: list[ParamDef] = []
    executor_ref: str


# ── Action 执行结果 ───────────────────────────────────────────────────────────

class ActionResult(BaseModel):
    success:       bool
    action_id:     str
    data:          dict[str, Any] = {}
    error_code:    Optional[str] = None
    error_message: Optional[str] = None
    fallback_used: bool = False

    @classmethod
    def ok(cls, action_id: str, render_type: RenderType, **data_kwargs) -> "ActionResult":
        """快捷构造成功结果"""
        return cls(
            success=True,
            action_id=action_id,
            data={"render_type": render_type.value, **data_kwargs},
        )

    @classmethod
    def fallback(cls, action_id: str, fallback_text: str, error_code: str = "executor_error") -> "ActionResult":
        """快捷构造兜底结果"""
        return cls(
            success=False,
            action_id=action_id,
            data={"render_type": RenderType.text.value, "text": fallback_text},
            error_code=error_code,
            fallback_used=True,
        )

    @classmethod
    def system_error(cls) -> "ActionResult":
        """Pipeline 顶层兜底"""
        return cls(
            success=False,
            action_id="system_error",
            data={"render_type": RenderType.text.value, "text": "系统繁忙，请稍后再试"},
            error_code="system_error",
            fallback_used=True,
        )

    @classmethod
    def param_fill(cls, action_id: str, missing_params: list[ParamDef], collected_params: dict) -> "ActionResult":
        """缺少必填参数时返回，触发前端补全卡片"""
        return cls(
            success=True,
            action_id=action_id,
            data={
                "render_type": RenderType.param_fill.value,
                "missing_params": [p.model_dump() for p in missing_params],
                "collected_params": collected_params,
            },
        )


# ── 意图映射结果 ──────────────────────────────────────────────────────────────

class IntentMapResult(BaseModel):
    action_id:  str
    params:     dict[str, Any] = {}
    confidence: float = 0.5     # 0.0–1.0，Rule 降级时固定 0.5
    degraded:   bool = False    # 是否走了降级路径


# ── CAS Router 请求/响应模型 ──────────────────────────────────────────────────

class DispatchIn(BaseModel):
    text:       str
    session_id: Optional[str] = None


class ActionSummary(BaseModel):
    action_id:   str
    name:        str
    description: str


class ActionsListOut(BaseModel):
    actions: list[ActionSummary]
    total:   int
