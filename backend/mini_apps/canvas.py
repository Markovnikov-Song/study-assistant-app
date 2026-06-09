from __future__ import annotations

from copy import deepcopy
from typing import Any

from .models import MiniAppValidation


class BlockRegistry:
    """Small typed block registry for the headless mini-app canvas."""

    def __init__(self) -> None:
        self.blocks: dict[str, dict[str, Any]] = {
            "document_source_loader": {
                "category": "content",
                "input_ports": {},
                "output_ports": {"chunks": "ChunkBatch"},
                "params_schema": {
                    "subject_id": "int",
                    "document_ids": "string",
                    "include_secondary": "bool",
                },
                "effects": {"reads": ["spec.content.source"], "writes": []},
            },
            "chunk_batch_processor": {
                "category": "content",
                "input_ports": {"chunks": "ChunkBatch"},
                "output_ports": {"chunks": "ChunkBatch"},
                "params_schema": {
                    "merge_under_tokens": "int",
                    "max_units": "int",
                    "min_unit_tokens": "int",
                    "cards_per_1000_tokens": "number",
                    "cards_per_section": "number",
                    "min_cards": "int",
                    "max_cards": "int",
                },
                "effects": {"reads": ["runtime.chunk_batch"], "writes": ["runtime.chunk_batch"]},
            },
            "flashcard_synthesizer": {
                "category": "content",
                "input_ports": {"chunks": "ChunkBatch"},
                "output_ports": {"items": "LearningItemBatch"},
                "params_schema": {
                    "style": "string",
                    "max_cards_per_unit": "int",
                },
                "requires": {"item_fields": ["front", "back"]},
                "effects": {"reads": ["runtime.chunk_batch"], "writes": ["spec.content.items"]},
            },
            "manual_card_loader": {
                "category": "content",
                "input_ports": {},
                "output_ports": {"items": "LearningItemBatch"},
                "params_schema": {
                    "source": "string",
                    "limit": "int",
                },
                "effects": {"reads": ["spec.content.items"], "writes": []},
            },
            "daily_quota_scheduler": {
                "category": "scheduler",
                "input_ports": {"items": "LearningItemBatch"},
                "output_ports": {"items": "LearningItemBatch"},
                "params_schema": {
                    "new_items_per_day": "int",
                    "max_reviews_per_day": "int",
                },
                "effects": {"reads": ["runtime.review_queue"], "writes": []},
            },
            "flashcard_practice": {
                "category": "practice",
                "input_ports": {"items": "LearningItemBatch"},
                "output_ports": {"answers": "AnswerEventBatch"},
                "params_schema": {
                    "mode": "string",
                },
                "requires": {"item_fields": ["front", "back"]},
                "effects": {"reads": ["runtime.current_items"], "writes": ["runtime.answers"]},
                "fallback": None,
            },
            "choice_quiz": {
                "category": "practice",
                "input_ports": {"items": "LearningItemBatch"},
                "output_ports": {"answers": "AnswerEventBatch"},
                "params_schema": {
                    "question_count": "int",
                    "difficulty": "string",
                },
                "requires": {"item_fields": ["front", "back"]},
                "effects": {"reads": ["runtime.current_items"], "writes": ["runtime.answers"]},
                "fallback": "flashcard_practice",
            },
            "spelling_input": {
                "category": "practice",
                "input_ports": {"items": "LearningItemBatch"},
                "output_ports": {"answers": "AnswerEventBatch"},
                "params_schema": {
                    "case_sensitive": "bool",
                },
                "requires": {"item_fields": ["front", "back"]},
                "effects": {"reads": ["runtime.current_items"], "writes": ["runtime.answers"]},
                "fallback": "flashcard_practice",
            },
            "exact_match_grader": {
                "category": "assessment",
                "input_ports": {"answers": "AnswerEventBatch"},
                "output_ports": {"graded": "GradeEventBatch"},
                "params_schema": {
                    "normalize": "bool",
                },
                "effects": {"reads": ["runtime.answers"], "writes": ["runtime.grades"]},
            },
            "answer_gate": {
                "category": "control",
                "input_ports": {"graded": "GradeEventBatch"},
                "output_ports": {
                    "correct": "GradeEventBatch",
                    "incorrect": "GradeEventBatch",
                },
                "params_schema": {
                    "wrong_before_hint": "int",
                },
                "effects": {"reads": ["runtime.grades"], "writes": []},
            },
            "show_hint": {
                "category": "feedback",
                "input_ports": {"graded": "GradeEventBatch"},
                "output_ports": {"feedback": "FeedbackEventBatch"},
                "params_schema": {
                    "style": "string",
                },
                "effects": {"reads": ["runtime.grades"], "writes": ["runtime.feedback"]},
            },
            "wrong_count_gate": {
                "category": "control",
                "input_ports": {"graded": "GradeEventBatch"},
                "output_ports": {
                    "hintable": "GradeEventBatch",
                    "explainable": "GradeEventBatch",
                },
                "params_schema": {
                    "wrong_before_explanation": "int",
                },
                "effects": {"reads": ["runtime.grades"], "writes": []},
            },
            "explanation_provider": {
                "category": "feedback",
                "input_ports": {"graded": "GradeEventBatch"},
                "output_ports": {"feedback": "FeedbackEventBatch"},
                "params_schema": {
                    "style": "string",
                },
                "effects": {"reads": ["runtime.grades"], "writes": ["runtime.feedback"]},
            },
            "mistake_book_writer": {
                "category": "persistence",
                "input_ports": {"graded": "GradeEventBatch"},
                "output_ports": {"graded": "GradeEventBatch"},
                "params_schema": {
                    "collection": "string",
                },
                "effects": {"reads": ["runtime.grades"], "writes": ["runtime.mistake_book"]},
            },
            "mastery_updater": {
                "category": "assessment",
                "input_ports": {"answers": "AnswerEventBatch", "graded": "GradeEventBatch"},
                "output_ports": {"mastery": "MasterySignalBatch"},
                "params_schema": {
                    "mastered_threshold": "number",
                    "wrong_before_explanation": "int",
                },
                "effects": {"reads": ["runtime.answers"], "writes": ["runtime.mastery"]},
            },
            "review_scheduler": {
                "category": "scheduler",
                "input_ports": {"mastery": "MasterySignalBatch"},
                "output_ports": {"tasks": "StudyTaskBatch"},
                "params_schema": {
                    "type": "string",
                    "wrong_answer_review_after_minutes": "int",
                },
                "effects": {"reads": ["runtime.mastery"], "writes": ["runtime.review_queue"]},
            },
            "summary_report": {
                "category": "feedback",
                "input_ports": {"tasks": "StudyTaskBatch"},
                "output_ports": {"progress": "ProgressEventBatch"},
                "params_schema": {},
                "effects": {"reads": ["runtime.review_queue"], "writes": ["runtime.progress"]},
            },
        }

    def get(self, block_id: str) -> dict[str, Any] | None:
        return self.blocks.get(block_id)

    def as_dict(self) -> dict[str, Any]:
        return {
            "schema_version": "miniapp.blocks.v1",
            "blocks": deepcopy(self.blocks),
            "categories": sorted(
                {str(block.get("category")) for block in self.blocks.values()}
            ),
        }


def get_block_registry() -> BlockRegistry:
    return BlockRegistry()


def _practice_block(step: str) -> str:
    normalized = str(step).strip().lower()
    if normalized in {"choice", "choice_quiz", "quiz"}:
        return "choice_quiz"
    if normalized in {"spelling", "spelling_input", "dictation"}:
        return "spelling_input"
    return "flashcard_practice"


def _practice_node_id(index: int, step: str) -> str:
    return f"practice_{index + 1}_{_practice_block(step).replace('_practice', '')}"


def _first_practice_node_id(sequence: list[Any]) -> str:
    return _practice_node_id(0, sequence[0] if sequence else "flashcard")


def _last_practice_node_id(sequence: list[Any]) -> str:
    index = max(len(sequence) - 1, 0)
    return _practice_node_id(index, sequence[index] if sequence else "flashcard")


def _practice_nodes(sequence: list[Any], scheduler: dict[str, Any]) -> list[dict[str, Any]]:
    nodes: list[dict[str, Any]] = []
    question_count = max(1, int(scheduler.get("new_items_per_day", 20)))
    for index, step in enumerate(sequence):
        block = _practice_block(str(step))
        params: dict[str, Any]
        if block == "choice_quiz":
            params = {"question_count": question_count, "difficulty": "normal"}
        elif block == "spelling_input":
            params = {"case_sensitive": False}
        else:
            params = {"mode": "self_rating"}
        nodes.append({
            "id": _practice_node_id(index, str(step)),
            "block": block,
            "params": params,
        })
    return nodes


def _practice_edges(sequence: list[Any]) -> list[dict[str, Any]]:
    edges: list[dict[str, Any]] = []
    for index in range(0, max(len(sequence) - 1, 0)):
        edges.append({
            "from": _practice_node_id(index, str(sequence[index])),
            "output": "answers",
            "to": _practice_node_id(index + 1, str(sequence[index + 1])),
            "input": "items",
            "adapter": "answers_to_items_passthrough",
        })
    return edges


def uses_document_pipeline(spec: dict[str, Any]) -> bool:
    content = spec.get("content") or {}
    if content.get("source_type") == "document":
        return True
    source = content.get("source")
    if isinstance(source, dict) and source.get("subject_id"):
        return True
    pipeline = content.get("pipeline")
    if isinstance(pipeline, list) and "document_source_loader" in pipeline:
        return True
    return False


def _content_source_params(spec: dict[str, Any]) -> dict[str, Any]:
    content = spec.get("content") or {}
    generation = content.get("generation") or {}
    source = content.get("source") if isinstance(content.get("source"), dict) else {}
    subject_id = source.get("subject_id") or (spec.get("app") or {}).get("subject_id")
    document_ids = source.get("document_ids") or []
    doc_id_str = ",".join(str(item) for item in document_ids) if document_ids else ""
    return {
        "subject_id": int(subject_id or 0),
        "document_ids": doc_id_str,
        "include_secondary": bool(source.get("include_secondary", False)),
        "merge_under_tokens": int(generation.get("merge_under_tokens", 120)),
        "max_units": int(generation.get("max_units", 48)),
        "min_unit_tokens": int(generation.get("min_unit_tokens", 40)),
        "cards_per_1000_tokens": float(generation.get("cards_per_1000_tokens", 4.0)),
        "cards_per_section": float(generation.get("cards_per_section", 2.0)),
        "min_cards": int(generation.get("min_cards", 8)),
        "max_cards": int(generation.get("max_cards", 120)),
        "style": str(generation.get("style", "qa")),
        "max_cards_per_unit": int(generation.get("max_cards_per_unit", 3)),
    }


def compile_spec_to_graph(spec: dict[str, Any]) -> dict[str, Any]:
    """Compile miniapp.v1 spec into a typed invisible canvas graph."""
    if uses_document_pipeline(spec):
        return _compile_document_pipeline_graph(spec)
    return _compile_manual_pipeline_graph(spec)


def _compile_document_pipeline_graph(spec: dict[str, Any]) -> dict[str, Any]:
    scheduler = spec.get("scheduler") or {}
    assessment = spec.get("assessment") or {}
    practice = spec.get("practice") or {}
    sequence = practice.get("sequence")
    if not isinstance(sequence, list) or not sequence:
        sequence = ["flashcard"]
    params = _content_source_params(spec)

    nodes = [
        {
            "id": "load_documents",
            "block": "document_source_loader",
            "params": {
                "subject_id": params["subject_id"],
                "document_ids": params["document_ids"],
                "include_secondary": params["include_secondary"],
            },
        },
        {
            "id": "process_chunks",
            "block": "chunk_batch_processor",
            "params": {
                "merge_under_tokens": params["merge_under_tokens"],
                "max_units": params["max_units"],
                "min_unit_tokens": params["min_unit_tokens"],
                "cards_per_1000_tokens": params["cards_per_1000_tokens"],
                "cards_per_section": params["cards_per_section"],
                "min_cards": params["min_cards"],
                "max_cards": params["max_cards"],
            },
        },
        {
            "id": "synthesize_cards",
            "block": "flashcard_synthesizer",
            "params": {
                "style": params["style"],
                "max_cards_per_unit": params["max_cards_per_unit"],
            },
        },
        {
            "id": "select_today",
            "block": "daily_quota_scheduler",
            "params": {
                "new_items_per_day": int(scheduler.get("new_items_per_day", 20)),
                "max_reviews_per_day": int(scheduler.get("max_reviews_per_day", 50)),
            },
        },
        *_practice_nodes(sequence, scheduler),
        {
            "id": "grade_answers",
            "block": "exact_match_grader",
            "params": {"normalize": True},
        },
        {
            "id": "answer_gate",
            "block": "answer_gate",
            "params": {
                "wrong_before_hint": int(assessment.get("wrong_before_explanation", 2)),
            },
        },
        {
            "id": "show_hint",
            "block": "show_hint",
            "params": {"style": "brief"},
        },
        {
            "id": "wrong_count_gate",
            "block": "wrong_count_gate",
            "params": {
                "wrong_before_explanation": int(assessment.get("wrong_before_explanation", 2)),
            },
        },
        {
            "id": "explain_answer",
            "block": "explanation_provider",
            "params": {"style": "worked_example"},
        },
        {
            "id": "save_mistake",
            "block": "mistake_book_writer",
            "params": {"collection": "default"},
        },
        {
            "id": "update_mastery",
            "block": "mastery_updater",
            "params": {
                "mastered_threshold": float(assessment.get("mastered_threshold", 0.85)),
                "wrong_before_explanation": int(assessment.get("wrong_before_explanation", 2)),
            },
        },
        {
            "id": "schedule_review",
            "block": "review_scheduler",
            "params": {
                "type": str(scheduler.get("type", "daily_fixed")),
                "wrong_answer_review_after_minutes": int(
                    scheduler.get("wrong_answer_review_after_minutes", 10)
                ),
            },
        },
        {
            "id": "summary",
            "block": "summary_report",
            "params": {},
        },
    ]

    edges = [
        {
            "from": "load_documents",
            "output": "chunks",
            "to": "process_chunks",
            "input": "chunks",
        },
        {
            "from": "process_chunks",
            "output": "chunks",
            "to": "synthesize_cards",
            "input": "chunks",
        },
        {
            "from": "synthesize_cards",
            "output": "items",
            "to": "select_today",
            "input": "items",
        },
        {
            "from": "select_today",
            "output": "items",
            "to": _first_practice_node_id(sequence),
            "input": "items",
        },
        *_practice_edges(sequence),
        {
            "from": _last_practice_node_id(sequence),
            "output": "answers",
            "to": "grade_answers",
            "input": "answers",
        },
        {
            "from": "grade_answers",
            "output": "graded",
            "to": "answer_gate",
            "input": "graded",
        },
        {
            "from": "answer_gate",
            "output": "incorrect",
            "to": "wrong_count_gate",
            "input": "graded",
            "when": "incorrect",
        },
        {
            "from": "wrong_count_gate",
            "output": "hintable",
            "to": "show_hint",
            "input": "graded",
            "when": "wrong_count_lt_threshold",
        },
        {
            "from": "wrong_count_gate",
            "output": "explainable",
            "to": "explain_answer",
            "input": "graded",
            "when": "wrong_count_gte_threshold",
        },
        {
            "from": "wrong_count_gate",
            "output": "explainable",
            "to": "save_mistake",
            "input": "graded",
            "when": "wrong_count_gte_threshold",
        },
        {
            "from": "answer_gate",
            "output": "correct",
            "to": "update_mastery",
            "input": "graded",
            "when": "correct",
        },
        {
            "from": "show_hint",
            "output": "feedback",
            "to": "update_mastery",
            "input": "graded",
            "adapter": "feedback_to_grade_passthrough",
            "when": "after_hint",
        },
        {
            "from": "explain_answer",
            "output": "feedback",
            "to": "update_mastery",
            "input": "graded",
            "adapter": "feedback_to_grade_passthrough",
            "when": "after_explanation",
        },
        {
            "from": "save_mistake",
            "output": "graded",
            "to": "update_mastery",
            "input": "graded",
            "when": "after_saved_mistake",
        },
        {
            "from": "update_mastery",
            "output": "mastery",
            "to": "schedule_review",
            "input": "mastery",
        },
        {
            "from": "schedule_review",
            "output": "tasks",
            "to": "summary",
            "input": "tasks",
        },
    ]

    return {
        "schema_version": "miniapp.graph.v1",
        "entry": "load_documents",
        "nodes": nodes,
        "edges": edges,
        "types": {
            "ChunkBatch": {"chunks": "Chunk[]", "units": "StudyUnit[]"},
            "LearningItemBatch": {"items": "LearningItem[]"},
            "AnswerEventBatch": {"answers": "AnswerEvent[]"},
            "GradeEventBatch": {"grades": "GradeEvent[]"},
            "FeedbackEventBatch": {"events": "FeedbackEvent[]"},
            "MasterySignalBatch": {"signals": "MasterySignal[]"},
            "StudyTaskBatch": {"tasks": "StudyTask[]"},
            "ProgressEventBatch": {"events": "ProgressEvent[]"},
        },
    }


def _compile_manual_pipeline_graph(spec: dict[str, Any]) -> dict[str, Any]:
    """Compile miniapp.v1 spec into a typed invisible canvas graph (manual items)."""
    scheduler = spec.get("scheduler") or {}
    assessment = spec.get("assessment") or {}
    content = spec.get("content") or {}
    items = content.get("items") if isinstance(content.get("items"), list) else []
    practice = spec.get("practice") or {}
    sequence = practice.get("sequence")
    if not isinstance(sequence, list) or not sequence:
        sequence = ["flashcard"]

    nodes = [
        {
            "id": "load_content",
            "block": "manual_card_loader",
            "params": {
                "source": "spec.content.items",
                "limit": len(items),
            },
        },
        {
            "id": "select_today",
            "block": "daily_quota_scheduler",
            "params": {
                "new_items_per_day": int(scheduler.get("new_items_per_day", 20)),
                "max_reviews_per_day": int(scheduler.get("max_reviews_per_day", 50)),
            },
        },
        *_practice_nodes(sequence, scheduler),
        {
            "id": "grade_answers",
            "block": "exact_match_grader",
            "params": {
                "normalize": True,
            },
        },
        {
            "id": "answer_gate",
            "block": "answer_gate",
            "params": {
                "wrong_before_hint": int(assessment.get("wrong_before_explanation", 2)),
            },
        },
        {
            "id": "show_hint",
            "block": "show_hint",
            "params": {
                "style": "brief",
            },
        },
        {
            "id": "wrong_count_gate",
            "block": "wrong_count_gate",
            "params": {
                "wrong_before_explanation": int(assessment.get("wrong_before_explanation", 2)),
            },
        },
        {
            "id": "explain_answer",
            "block": "explanation_provider",
            "params": {
                "style": "worked_example",
            },
        },
        {
            "id": "save_mistake",
            "block": "mistake_book_writer",
            "params": {
                "collection": "default",
            },
        },
        {
            "id": "update_mastery",
            "block": "mastery_updater",
            "params": {
                "mastered_threshold": float(assessment.get("mastered_threshold", 0.85)),
                "wrong_before_explanation": int(assessment.get("wrong_before_explanation", 2)),
            },
        },
        {
            "id": "schedule_review",
            "block": "review_scheduler",
            "params": {
                "type": str(scheduler.get("type", "daily_fixed")),
                "wrong_answer_review_after_minutes": int(
                    scheduler.get("wrong_answer_review_after_minutes", 10)
                ),
            },
        },
        {
            "id": "summary",
            "block": "summary_report",
            "params": {},
        },
    ]

    edges = [
        {
            "from": "load_content",
            "output": "items",
            "to": "select_today",
            "input": "items",
        },
        {
            "from": "select_today",
            "output": "items",
            "to": _first_practice_node_id(sequence),
            "input": "items",
        },
        *_practice_edges(sequence),
        {
            "from": _last_practice_node_id(sequence),
            "output": "answers",
            "to": "grade_answers",
            "input": "answers",
        },
        {
            "from": "grade_answers",
            "output": "graded",
            "to": "answer_gate",
            "input": "graded",
        },
        {
            "from": "answer_gate",
            "output": "incorrect",
            "to": "wrong_count_gate",
            "input": "graded",
            "when": "incorrect",
        },
        {
            "from": "wrong_count_gate",
            "output": "hintable",
            "to": "show_hint",
            "input": "graded",
            "when": "wrong_count_lt_threshold",
        },
        {
            "from": "wrong_count_gate",
            "output": "explainable",
            "to": "explain_answer",
            "input": "graded",
            "when": "wrong_count_gte_threshold",
        },
        {
            "from": "wrong_count_gate",
            "output": "explainable",
            "to": "save_mistake",
            "input": "graded",
            "when": "wrong_count_gte_threshold",
        },
        {
            "from": "answer_gate",
            "output": "correct",
            "to": "update_mastery",
            "input": "graded",
            "when": "correct",
        },
        {
            "from": "show_hint",
            "output": "feedback",
            "to": "update_mastery",
            "input": "graded",
            "adapter": "feedback_to_grade_passthrough",
            "when": "after_hint",
        },
        {
            "from": "explain_answer",
            "output": "feedback",
            "to": "update_mastery",
            "input": "graded",
            "adapter": "feedback_to_grade_passthrough",
            "when": "after_explanation",
        },
        {
            "from": "save_mistake",
            "output": "graded",
            "to": "update_mastery",
            "input": "graded",
            "when": "after_saved_mistake",
        },
        {
            "from": "update_mastery",
            "output": "mastery",
            "to": "schedule_review",
            "input": "mastery",
        },
        {
            "from": "schedule_review",
            "output": "tasks",
            "to": "summary",
            "input": "tasks",
        },
    ]

    return {
        "schema_version": "miniapp.graph.v1",
        "entry": "load_content",
        "nodes": nodes,
        "edges": edges,
        "types": {
            "ChunkBatch": {"chunks": "Chunk[]", "units": "StudyUnit[]"},
            "LearningItemBatch": {"items": "LearningItem[]"},
            "AnswerEventBatch": {"answers": "AnswerEvent[]"},
            "GradeEventBatch": {"grades": "GradeEvent[]"},
            "FeedbackEventBatch": {"events": "FeedbackEvent[]"},
            "MasterySignalBatch": {"signals": "MasterySignal[]"},
            "StudyTaskBatch": {"tasks": "StudyTask[]"},
            "ProgressEventBatch": {"events": "ProgressEvent[]"},
        },
    }


def validate_graph(graph: dict[str, Any], spec: dict[str, Any] | None = None) -> MiniAppValidation:
    registry = get_block_registry()
    errors: list[str] = []
    warnings: list[str] = []
    _validate_graph_collections(graph, errors)
    nodes, edges = _graph_parts(graph)
    node_by_id = _node_by_id(nodes)

    entry = graph.get("entry")
    _validate_graph_entry(entry, node_by_id, errors)
    _validate_graph_nodes(nodes, registry, errors)
    _validate_graph_edges(edges, node_by_id, registry, errors, warnings)

    _validate_acyclic(nodes, edges, errors)
    _validate_reachable(entry, nodes, edges, errors)
    if spec is not None:
        _validate_item_requirements(nodes, spec, registry, errors, warnings)

    return MiniAppValidation(ok=not errors, errors=errors, warnings=warnings)


def _validate_graph_collections(graph: dict[str, Any], errors: list[str]) -> None:
    for key in ("nodes", "edges"):
        value = graph.get(key)
        if not isinstance(value, list):
            errors.append(f"graph.{key} must be a list")
            continue
        for index, item in enumerate(value):
            if not isinstance(item, dict):
                errors.append(f"graph.{key}[{index}] must be an object")


def _graph_parts(graph: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    raw_nodes = graph.get("nodes")
    raw_edges = graph.get("edges")
    nodes = [item for item in raw_nodes if isinstance(item, dict)] if isinstance(raw_nodes, list) else []
    edges = [item for item in raw_edges if isinstance(item, dict)] if isinstance(raw_edges, list) else []
    return nodes, edges


def _node_by_id(nodes: list[dict[str, Any]]) -> dict[Any, dict[str, Any]]:
    return {node.get("id"): node for node in nodes}


def _validate_graph_entry(
    entry: Any,
    node_by_id: dict[Any, dict[str, Any]],
    errors: list[str],
) -> None:
    if not entry or entry not in node_by_id:
        errors.append("graph.entry must reference an existing node")


def _validate_graph_nodes(
    nodes: list[dict[str, Any]],
    registry: BlockRegistry,
    errors: list[str],
) -> None:
    seen_ids: set[str] = set()
    for node in nodes:
        node_id = str(node.get("id") or "")
        if not node_id:
            errors.append("Graph node id cannot be empty")
        elif node_id in seen_ids:
            errors.append(f"Duplicate graph node id: {node_id}")
        seen_ids.add(node_id)
        _validate_graph_node_params(node, registry, errors)


def _validate_graph_node_params(
    node: dict[str, Any],
    registry: BlockRegistry,
    errors: list[str],
) -> None:
    block_id = node.get("block")
    block = registry.get(str(block_id))
    if block is None:
        errors.append(f"Unknown block: {block_id}")
        return
    params = node.get("params") if isinstance(node.get("params"), dict) else {}
    for key, expected in (block.get("params_schema") or {}).items():
        if key not in params:
            errors.append(f"{node.get('id')}.{key} is required")
            continue
        if not _matches_type(params[key], expected):
            errors.append(f"{node.get('id')}.{key} must be {expected}")


def _validate_graph_edges(
    edges: list[dict[str, Any]],
    node_by_id: dict[Any, dict[str, Any]],
    registry: BlockRegistry,
    errors: list[str],
    warnings: list[str],
) -> None:
    for edge in edges:
        source = node_by_id.get(edge.get("from"))
        target = node_by_id.get(edge.get("to"))
        if source is None or target is None:
            errors.append(f"Edge references missing node: {edge}")
            continue
        _validate_graph_edge_ports(edge, source, target, registry, errors, warnings)


def _validate_graph_edge_ports(
    edge: dict[str, Any],
    source: dict[str, Any],
    target: dict[str, Any],
    registry: BlockRegistry,
    errors: list[str],
    warnings: list[str],
) -> None:
    source_block = registry.get(str(source.get("block"))) or {}
    target_block = registry.get(str(target.get("block"))) or {}
    source_type = (source_block.get("output_ports") or {}).get(edge.get("output"))
    target_type = (target_block.get("input_ports") or {}).get(edge.get("input"))
    if source_type is None:
        errors.append(f"{source.get('id')} has no output port {edge.get('output')}")
    if target_type is None:
        errors.append(f"{target.get('id')} has no input port {edge.get('input')}")
    if not source_type or not target_type or source_type == target_type:
        return
    if edge.get("adapter") is None:
        errors.append(
            f"Type mismatch: {source.get('id')}.{edge.get('output')} "
            f"{source_type} -> {target.get('id')}.{edge.get('input')} {target_type}"
        )
    else:
        warnings.append(
            f"Adapter {edge.get('adapter')} bridges {source_type} -> {target_type}"
        )


def execute_graph_preview(graph: dict[str, Any], spec: dict[str, Any]) -> dict[str, Any]:
    """Deterministic preview executor for smoke tests and future server-side runtime."""
    graph_validation = validate_graph(graph, spec)
    if not graph_validation.ok:
        return {
            "ok": False,
            "errors": graph_validation.errors,
            "messages": {},
        }

    content = spec.get("content") or {}
    items = list(content.get("items") or [])
    scheduler = spec.get("scheduler") or {}
    limit = int(scheduler.get("new_items_per_day", len(items) or 1))
    selected = items[: max(limit, 0)]
    messages = {
        "load_content": {"items": items},
        "select_today": {"items": selected},
        _last_practice_node_id(
            ((spec.get("practice") or {}).get("sequence") or ["flashcard"])
        ): {
            "answers": [
                {"item_id": item.get("id"), "known": None}
                for item in selected
                if isinstance(item, dict)
            ]
        },
        "grade_answers": {"grades": []},
        "answer_gate": {"correct": [], "incorrect": []},
        "wrong_count_gate": {"hintable": [], "explainable": []},
        "show_hint": {"events": []},
        "explain_answer": {"events": []},
        "save_mistake": {"graded": []},
        "update_mastery": {"signals": []},
        "schedule_review": {"tasks": []},
        "summary": {
            "events": [
                {
                    "kind": "preview",
                    "item_count": len(selected),
                    "scheduler": scheduler.get("type", "daily_fixed"),
                }
            ]
        },
    }
    return {"ok": True, "errors": [], "messages": messages}


def merge_validations(*validations: MiniAppValidation) -> MiniAppValidation:
    errors: list[str] = []
    warnings: list[str] = []
    for validation in validations:
        errors.extend(validation.errors)
        warnings.extend(validation.warnings)
    seen_warnings: list[str] = []
    for warning in warnings:
        if warning not in seen_warnings:
            seen_warnings.append(warning)
    return MiniAppValidation(ok=not errors, errors=errors, warnings=seen_warnings)


def materialize_graph(spec: dict[str, Any]) -> tuple[dict[str, Any], MiniAppValidation]:
    graph = compile_spec_to_graph(spec)
    return graph, validate_graph(graph, spec)


def _matches_type(value: Any, expected: str) -> bool:
    if expected == "string":
        return isinstance(value, str)
    if expected == "int":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "bool":
        return isinstance(value, bool)
    return True


def _validate_acyclic(nodes: list[dict[str, Any]], edges: list[dict[str, Any]], errors: list[str]) -> None:
    node_ids = [node.get("id") for node in nodes]
    outgoing: dict[str, list[str]] = {str(node_id): [] for node_id in node_ids}
    indegree: dict[str, int] = {str(node_id): 0 for node_id in node_ids}
    for edge in edges:
        source = str(edge.get("from"))
        target = str(edge.get("to"))
        if source not in outgoing or target not in indegree:
            continue
        outgoing[source].append(target)
        indegree[target] += 1
    queue = [node_id for node_id, degree in indegree.items() if degree == 0]
    visited = 0
    while queue:
        node_id = queue.pop(0)
        visited += 1
        for target in outgoing.get(node_id, []):
            indegree[target] -= 1
            if indegree[target] == 0:
                queue.append(target)
    if visited != len(indegree):
        errors.append("Graph contains an illegal cycle")


def _validate_reachable(
    entry: str | None,
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    errors: list[str],
) -> None:
    if not entry:
        return
    node_ids = {str(node.get("id")) for node in nodes}
    outgoing: dict[str, list[str]] = {node_id: [] for node_id in node_ids}
    for edge in edges:
        source = str(edge.get("from"))
        target = str(edge.get("to"))
        if source in outgoing:
            outgoing[source].append(target)
    seen: set[str] = set()
    stack = [str(entry)]
    while stack:
        node_id = stack.pop()
        if node_id in seen:
            continue
        seen.add(node_id)
        stack.extend(outgoing.get(node_id, []))
    unreachable = sorted(node_ids - seen)
    if unreachable:
        errors.append(f"Unreachable graph node(s): {', '.join(unreachable)}")


def _validate_item_requirements(
    nodes: list[dict[str, Any]],
    spec: dict[str, Any],
    registry: BlockRegistry,
    errors: list[str],
    warnings: list[str],
) -> None:
    content = spec.get("content") or {}
    items = content.get("items") or []
    document_pipeline = uses_document_pipeline(spec)
    if document_pipeline and not items:
        warnings.append(
            "资料管线已配置，但尚未生成闪卡；请调用「从资料生成闪卡」写入 content.items。"
        )
        return

    for node in nodes:
        block = registry.get(str(node.get("block"))) or {}
        required_fields = ((block.get("requires") or {}).get("item_fields") or [])
        if not required_fields:
            continue
        if document_pipeline and str(node.get("block")) == "flashcard_synthesizer" and not items:
            continue
        for index, item in enumerate(items):
            if not isinstance(item, dict):
                continue
            missing = [field for field in required_fields if not item.get(field)]
            if missing:
                errors.append(
                    f"{node.get('id')} requires item {index} fields: {', '.join(missing)}"
                )
    if len(items) < 5:
        warnings.append("Graph is valid, but content has fewer than 5 items.")
