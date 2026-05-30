"""
CAS 接线检查：Executor 装饰器注册 vs Action YAML 定义必须一致。
"""
from __future__ import annotations

import ast
import logging
from pathlib import Path

from .action_registry import get_action_registry
from .executor_registry import get_executor, list_registered_executors

logger = logging.getLogger(__name__)

_EXECUTORS_DIR = Path(__file__).parent / "executors"


def scan_executor_ids_from_source() -> set[str]:
    """从 @register_executor 源码扫描 action_id（不依赖 import 顺序）。"""
    ids: set[str] = set()
    for path in _EXECUTORS_DIR.glob("*.py"):
        if path.name.startswith("_"):
            continue
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            func = node.func
            if not (
                isinstance(func, ast.Name)
                and func.id == "register_executor"
                or isinstance(func, ast.Attribute)
                and func.attr == "register_executor"
            ):
                continue
            if node.args and isinstance(node.args[0], ast.Constant) and isinstance(
                node.args[0].value, str
            ):
                ids.add(node.args[0].value)
    return ids


def audit_cas_wiring(*, load_executors: bool = True) -> dict[str, list[str]]:
    """
    返回接线缺口（均为应修复项，不含 unknown_intent 等特殊说明）。
    """
    if load_executors:
        _import_all_executors()

    registry = get_action_registry()
    action_defs = registry.list_actions()
    action_ids = {a.action_id for a in action_defs}
    executor_ids = set(list_registered_executors())
    source_ids = scan_executor_ids_from_source()

    executors_without_action = sorted(
        (executor_ids | source_ids) - action_ids - {"unknown_intent"}
    )
    actions_without_executor = sorted(
        a.action_id
        for a in action_defs
        if get_executor(a.executor_ref) is None and a.action_id != "unknown_intent"
    )
    executor_ref_mismatch = sorted(
        a.action_id
        for a in action_defs
        if a.executor_ref != a.action_id and get_executor(a.executor_ref) is None
    )
    orphan_source = sorted(source_ids - executor_ids)

    return {
        "executors_without_action": executors_without_action,
        "actions_without_executor": actions_without_executor,
        "executor_ref_mismatch": executor_ref_mismatch,
        "source_not_imported": orphan_source,
    }


def assert_cas_wiring_ok(*, load_executors: bool = True) -> None:
    gaps = audit_cas_wiring(load_executors=load_executors)
    problems: list[str] = []
    if gaps["executors_without_action"]:
        problems.append(
            "Executor 未在 prompts/actions/builtin.yaml 注册: "
            + ", ".join(gaps["executors_without_action"])
        )
    if gaps["actions_without_executor"]:
        problems.append(
            "Action 无对应 Executor 实现: "
            + ", ".join(gaps["actions_without_executor"])
        )
    if gaps["executor_ref_mismatch"]:
        problems.append(
            "executor_ref 无法解析: " + ", ".join(gaps["executor_ref_mismatch"])
        )
    if problems:
        raise RuntimeError("; ".join(problems))


def _import_all_executors() -> None:
    import cas.executors.add_calendar_event  # noqa: F401
    import cas.executors.create_mini_app  # noqa: F401
    import cas.executors.explain_concept  # noqa: F401
    import cas.executors.generate_mindmap  # noqa: F401
    import cas.executors.make_plan  # noqa: F401
    import cas.executors.make_quiz  # noqa: F401
    import cas.executors.open_calendar  # noqa: F401
    import cas.executors.open_course_space  # noqa: F401
    import cas.executors.open_notebook  # noqa: F401
    import cas.executors.recommend_mistake_practice  # noqa: F401
    import cas.executors.solve_problem  # noqa: F401
    import cas.executors.start_feynman  # noqa: F401
    import cas.executors.unknown_intent  # noqa: F401
