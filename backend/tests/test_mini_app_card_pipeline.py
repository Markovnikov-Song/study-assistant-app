from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from mini_apps.canvas import compile_spec_to_graph, get_block_registry, uses_document_pipeline, validate_graph
from mini_apps.content_pipeline import (
    ChunkBatch,
    ProcessedUnit,
    RawChunk,
    process_chunk_batch,
    synthesize_flashcards,
)
from mini_apps.builder import build_spec, infer_content_binding, validate_spec


def test_document_pipeline_blocks_registered():
    registry = get_block_registry()
    for block_id in (
        "document_source_loader",
        "chunk_batch_processor",
        "flashcard_synthesizer",
    ):
        assert registry.get(block_id) is not None


def test_document_spec_compiles_to_loader_graph():
    spec = {
        "schema_version": "miniapp.v1",
        "app": {"type": "memory", "title": "测试", "subject_id": 1},
        "content": {
            "source_type": "document",
            "source": {"subject_id": 1, "document_ids": []},
            "pipeline": [
                "document_source_loader",
                "chunk_batch_processor",
                "flashcard_synthesizer",
            ],
            "generation": {"min_cards": 8, "max_cards": 40},
            "items": [],
        },
        "screens": ["card_practice"],
        "scheduler": {"type": "daily_fixed", "new_items_per_day": 10, "max_reviews_per_day": 30},
        "assessment": {"mastered_threshold": 0.85, "wrong_before_explanation": 2},
        "practice": {"sequence": ["flashcard"]},
        "runtime": {"engine": "flashcard_runtime", "safe_blocks": []},
    }
    assert uses_document_pipeline(spec)
    graph = compile_spec_to_graph(spec)
    assert graph["entry"] == "load_documents"
    node_blocks = {node["block"] for node in graph["nodes"]}
    assert "document_source_loader" in node_blocks
    assert "chunk_batch_processor" in node_blocks
    assert "flashcard_synthesizer" in node_blocks
    validation = validate_graph(graph, spec)
    assert validation.ok


def test_validate_graph_reports_node_and_edge_contract_errors():
    graph = {
        "schema_version": "miniapp.graph.v1",
        "entry": "load_content",
        "nodes": [
            {
                "id": "load_content",
                "block": "manual_card_loader",
                "params": {"source": "spec.content.items", "limit": "bad"},
            },
            {
                "id": "select_today",
                "block": "daily_quota_scheduler",
                "params": {"new_items_per_day": 10, "max_reviews_per_day": 30},
            },
        ],
        "edges": [
            {
                "from": "load_content",
                "output": "missing",
                "to": "select_today",
                "input": "items",
            }
        ],
    }

    validation = validate_graph(graph, _manual_spec())

    assert not validation.ok
    errors = "\n".join(validation.errors)
    assert "load_content.limit must be int" in errors
    assert "load_content has no output port missing" in errors


def test_validate_graph_reports_malformed_collections():
    validation = validate_graph(
        {
            "schema_version": "miniapp.graph.v1",
            "entry": "load_content",
            "nodes": [{"id": "load_content", "block": "manual_card_loader", "params": {}}, "bad"],
            "edges": {"from": "load_content"},
        },
        _manual_spec(),
    )

    assert not validation.ok
    errors = "\n".join(validation.errors)
    assert "graph.nodes[1] must be an object" in errors
    assert "graph.edges must be a list" in errors


def test_process_chunks_estimates_dynamic_card_count():
    chunks = [
        RawChunk(
            id=i,
            document_id=1,
            chunk_index=i,
            content=f"第{i}段材料力学内容，讨论应力应变与本构关系。" * 3,
            heading_path="第1章" if i < 3 else "第2章",
            token_count=80,
            is_secondary=False,
        )
        for i in range(6)
    ]
    batch = ChunkBatch(chunks=chunks)
    processed = process_chunk_batch(
        batch,
        {
            "merge_under_tokens": 100,
            "max_units": 10,
            "min_cards": 8,
            "max_cards": 120,
            "cards_per_1000_tokens": 4,
            "cards_per_section": 2,
        },
    )
    assert processed.target_card_count >= 8
    assert processed.target_card_count <= 120
    assert len(processed.units) >= 2


def test_synthesize_without_llm_produces_cards():
    unit = ProcessedUnit(
        unit_id="unit_1",
        document_id=1,
        heading_path="运动学",
        text="位移与应变之间存在几何关系，应变张量描述变形程度。",
        token_count=60,
        source_chunk_ids=[1],
    )
    batch = ChunkBatch(units=[unit], target_card_count=3)
    items, meta = synthesize_flashcards(
        batch,
        {"style": "qa", "max_cards_per_unit": 2},
        use_llm=False,
    )
    assert len(items) >= 1
    assert items[0]["front"]
    assert items[0]["back"]
    assert meta["actual_card_count"] == len(items)


def test_build_spec_uses_document_binding_when_mentioned():
    session = {
        "initial_request": "用资料库的材料力学讲义做闪卡",
        "answers": ["学科资料库", "每天20张", "答错两次讲解"],
        "subject_id": 9,
    }
    binding = infer_content_binding(session, session["answers"], session["initial_request"])
    assert binding["source_type"] == "document"
    spec = build_spec(session)
    assert spec["content"]["source_type"] == "document"
    assert spec["content"]["items"] == []
    validation = validate_spec(spec)
    assert validation.ok
    assert any("尚未从资料生成" in warning for warning in validation.warnings)


def _manual_spec() -> dict:
    return {
        "schema_version": "miniapp.v1",
        "app": {"type": "memory", "title": "测试", "subject_id": 1},
        "content": {
            "source_type": "manual",
            "items": [
                {"id": "card_1", "front": "A", "back": "B"},
                {"id": "card_2", "front": "C", "back": "D"},
                {"id": "card_3", "front": "E", "back": "F"},
                {"id": "card_4", "front": "G", "back": "H"},
                {"id": "card_5", "front": "I", "back": "J"},
            ],
        },
        "screens": ["card_practice"],
        "scheduler": {"type": "daily_fixed", "new_items_per_day": 10, "max_reviews_per_day": 30},
        "assessment": {"mastered_threshold": 0.85, "wrong_before_explanation": 2},
        "practice": {"sequence": ["flashcard"]},
        "runtime": {"engine": "flashcard_runtime", "safe_blocks": []},
    }
