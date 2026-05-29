from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from services.exam_prep_orchestrator import ExamPrepOrchestrator
from services.study_planner_service import (
    _capability_binding_for_node,
    _extract_nodes_from_markdown,
    _fallback_mindmap_for_subject,
)


def test_exam_prep_infers_material_mechanics_subject():
    orchestrator = ExamPrepOrchestrator()

    assert orchestrator.infer_subject_name("我要备考材料力学") == "材料力学"


def test_material_mechanics_fallback_mindmap_has_schedulable_nodes():
    mindmap = _fallback_mindmap_for_subject("材料力学")
    nodes = _extract_nodes_from_markdown(mindmap)

    assert len(nodes) >= 20
    assert any(node["text"] == "弯曲应力" for node in nodes)
    assert any(node["text"] == "压杆稳定" for node in nodes)


def test_material_mechanics_nodes_bind_to_practice_and_memory_apps():
    quiz_capability, quiz_params, _ = _capability_binding_for_node({
        "text": "剪力图与弯矩图",
        "subject_name": "材料力学",
        "estimated_minutes": 30,
    })
    memory_capability, memory_params, _ = _capability_binding_for_node({
        "text": "弯曲强度条件",
        "subject_name": "材料力学",
        "estimated_minutes": 30,
    })

    assert quiz_capability == "quiz.generate"
    assert quiz_params["count"] >= 3
    assert memory_capability == "memory.drill"
    assert memory_params["content_type"] == "formula"
