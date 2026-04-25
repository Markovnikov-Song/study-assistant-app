"""
ActionRegistry — 从 YAML 文件加载 Action 定义，复用 SkillRegistry 的单例 + 懒加载模式。

用法：
    from cas.action_registry import get_action_registry

    registry = get_action_registry()
    action = registry.get_action("make_quiz")   # 返回 ActionDef 或 None
    actions = registry.list_actions()           # 全部 ActionDef
    summary = registry.summaries()              # 供 LLM 提示词使用的摘要文本
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Optional

import yaml

from .models import ActionDef, ParamDef, ParamType

logger = logging.getLogger(__name__)

_ACTIONS_YAML = Path(__file__).parent.parent / "prompts" / "actions" / "builtin.yaml"

# 合法参数类型集合（用于校验）
_VALID_PARAM_TYPES = {pt.value for pt in ParamType}


class ActionRegistry:
    """
    单例 Action 注册表。
    从 YAML 文件懒加载，支持热重载（调用 reload()）。
    加载失败时以空注册表启动，不阻断服务。
    """

    _instance: Optional["ActionRegistry"] = None
    _actions: list[ActionDef] = []
    _index: dict[str, ActionDef] = {}
    _loaded: bool = False

    def __new__(cls) -> "ActionRegistry":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def _ensure_loaded(self) -> None:
        if not self._loaded:
            self._load()

    def _load(self) -> None:
        """从 YAML 文件加载 Action 定义，失败时保留现有数据（降级）。"""
        try:
            with open(_ACTIONS_YAML, encoding="utf-8") as f:
                data = yaml.safe_load(f)

            raw_actions = data.get("actions", [])
            valid_actions: list[ActionDef] = []

            for raw in raw_actions:
                action_id = raw.get("action_id", "")

                # 校验必要字段
                required_fields = {"action_id", "name", "description", "param_schema", "executor_ref"}
                missing = required_fields - set(raw.keys())
                if missing:
                    logger.warning("ActionRegistry: Action '%s' 缺少必要字段 %s，已跳过", action_id, missing)
                    continue

                # 校验参数类型
                param_schema_raw = raw.get("param_schema", [])
                valid_params: list[ParamDef] = []
                skip_action = False

                for param_raw in param_schema_raw:
                    param_type = param_raw.get("type", "")
                    if param_type not in _VALID_PARAM_TYPES:
                        logger.warning(
                            "ActionRegistry: Action '%s' 的参数 '%s' 类型 '%s' 非法，已跳过该 Action",
                            action_id, param_raw.get("name", "?"), param_type,
                        )
                        skip_action = True
                        break
                    valid_params.append(ParamDef(**param_raw))

                if skip_action:
                    continue

                try:
                    action = ActionDef(
                        action_id=raw["action_id"],
                        version=raw.get("version", "1.0.0"),
                        name=raw["name"],
                        description=raw["description"],
                        fallback_text=raw.get("fallback_text", "操作暂时不可用，请稍后再试"),
                        param_schema=valid_params,
                        executor_ref=raw["executor_ref"],
                    )
                    valid_actions.append(action)
                except Exception as e:
                    logger.warning("ActionRegistry: Action '%s' 解析失败：%s，已跳过", action_id, e)
                    continue

            self._actions = valid_actions
            self._index = {a.action_id: a for a in valid_actions}
            self._loaded = True
            logger.info("ActionRegistry: 加载完成，共 %d 个 Action", len(valid_actions))

        except FileNotFoundError:
            logger.error("ActionRegistry: YAML 文件不存在：%s，以空注册表启动", _ACTIONS_YAML)
            self._loaded = True
        except Exception as e:
            logger.error("ActionRegistry: 加载失败：%s，以空注册表启动", e)
            self._loaded = True

    def reload(self) -> None:
        """清空缓存，重新从 YAML 加载（热更新用）。"""
        self._loaded = False
        self._actions = []
        self._index = {}
        self._load()

    # ── 查询接口 ──────────────────────────────────────────────────────────────

    def get_action(self, action_id: str) -> Optional[ActionDef]:
        """按 action_id 获取 ActionDef，不存在返回 None，永不抛出异常。"""
        self._ensure_loaded()
        return self._index.get(action_id)

    def list_actions(self) -> list[ActionDef]:
        """返回所有已注册 ActionDef 列表。"""
        self._ensure_loaded()
        return list(self._actions)

    def summaries(self) -> str:
        """
        生成供 LLM 提示词使用的 Action 摘要文本。
        格式：- action_id：name（description）
        """
        self._ensure_loaded()
        return "\n".join(
            f"- {a.action_id}：{a.name}（{a.description}）"
            for a in self._actions
        )


# ── 模块级单例访问 ─────────────────────────────────────────────────────────────

_registry: Optional[ActionRegistry] = None


def get_action_registry() -> ActionRegistry:
    """获取全局 ActionRegistry 单例。"""
    global _registry
    if _registry is None:
        _registry = ActionRegistry()
    return _registry
