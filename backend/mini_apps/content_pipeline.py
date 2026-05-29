"""
Document → chunk processing → flashcard synthesis pipeline for mini-apps.

Executed by typed canvas blocks:
  document_source_loader → chunk_batch_processor → flashcard_synthesizer
"""
from __future__ import annotations

import json
import logging
import math
import re
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger(__name__)


@dataclass
class RawChunk:
    id: int
    document_id: int
    chunk_index: int
    content: str
    heading_path: str | None
    token_count: int
    is_secondary: bool


@dataclass
class ProcessedUnit:
    unit_id: str
    document_id: int
    heading_path: str
    text: str
    token_count: int
    source_chunk_ids: list[int] = field(default_factory=list)


@dataclass
class ChunkBatch:
    chunks: list[RawChunk] = field(default_factory=list)
    units: list[ProcessedUnit] = field(default_factory=list)
    total_tokens: int = 0
    target_card_count: int = 0
    meta: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "chunks": [
                {
                    "id": c.id,
                    "document_id": c.document_id,
                    "chunk_index": c.chunk_index,
                    "heading_path": c.heading_path,
                    "token_count": c.token_count,
                    "is_secondary": c.is_secondary,
                    "content_preview": c.content[:240],
                }
                for c in self.chunks
            ],
            "units": [
                {
                    "unit_id": u.unit_id,
                    "document_id": u.document_id,
                    "heading_path": u.heading_path,
                    "token_count": u.token_count,
                    "source_chunk_ids": u.source_chunk_ids,
                    "text_preview": u.text[:320],
                }
                for u in self.units
            ],
            "total_tokens": self.total_tokens,
            "target_card_count": self.target_card_count,
            "meta": self.meta,
        }


def _estimate_tokens(text: str) -> int:
    if not text:
        return 0
    # 中英文混合粗估：约 2 字符 ≈ 1 token
    return max(1, len(text) // 2)


def load_document_chunks(
    user_id: int,
    subject_id: int,
    document_ids: list[int] | None = None,
    *,
    include_secondary: bool = False,
) -> ChunkBatch:
    from database import Chunk, Document, get_session

    with get_session() as db:
        query = (
            db.query(Chunk)
            .join(Document, Chunk.document_id == Document.id)
            .filter(
                Document.user_id == user_id,
                Chunk.subject_id == subject_id,
                Document.status == "completed",
            )
        )
        if document_ids:
            query = query.filter(Chunk.document_id.in_(document_ids))
        rows = query.order_by(Chunk.document_id, Chunk.chunk_index).all()

    chunks: list[RawChunk] = []
    for row in rows:
        if row.is_secondary and not include_secondary:
            continue
        content = (row.content or "").strip()
        if len(content) < 20:
            continue
        token_count = int(row.token_count or 0) or _estimate_tokens(content)
        chunks.append(
            RawChunk(
                id=int(row.id),
                document_id=int(row.document_id),
                chunk_index=int(row.chunk_index),
                content=content,
                heading_path=(row.heading_path or "").strip() or "未分类",
                token_count=token_count,
                is_secondary=bool(row.is_secondary),
            )
        )

    return ChunkBatch(chunks=chunks, meta={"loaded_count": len(chunks)})


def process_chunk_batch(batch: ChunkBatch, params: dict[str, Any]) -> ChunkBatch:
    """Post-process loaded chunks into study units and estimate card budget."""
    merge_under = int(params.get("merge_under_tokens", 120))
    max_units = int(params.get("max_units", 48))
    min_unit_tokens = int(params.get("min_unit_tokens", 40))

    cards_per_1000 = float(params.get("cards_per_1000_tokens", 4.0))
    cards_per_section = float(params.get("cards_per_section", 2.0))
    min_cards = int(params.get("min_cards", 8))
    max_cards = int(params.get("max_cards", 120))

    units: list[ProcessedUnit] = []
    buffer: list[RawChunk] = []
    buffer_tokens = 0

    def flush_buffer() -> None:
        nonlocal buffer, buffer_tokens
        if not buffer:
            return
        text = "\n\n".join(c.content for c in buffer)
        heading = buffer[0].heading_path or "未分类"
        units.append(
            ProcessedUnit(
                unit_id=f"unit_{len(units) + 1}",
                document_id=buffer[0].document_id,
                heading_path=heading,
                text=text,
                token_count=sum(c.token_count for c in buffer),
                source_chunk_ids=[c.id for c in buffer],
            )
        )
        buffer = []
        buffer_tokens = 0

    for chunk in batch.chunks:
        if buffer and chunk.heading_path != buffer[-1].heading_path:
            flush_buffer()
        buffer.append(chunk)
        buffer_tokens += chunk.token_count
        if buffer_tokens >= merge_under:
            flush_buffer()
    flush_buffer()

    filtered: list[ProcessedUnit] = []
    for unit in units:
        if unit.token_count < min_unit_tokens and len(units) > 1:
            continue
        filtered.append(unit)
    units = filtered[:max_units]

    total_tokens = sum(u.token_count for u in units)
    section_count = len({u.heading_path for u in units}) or 1
    by_tokens = math.ceil(total_tokens / 1000.0 * cards_per_1000) if total_tokens else 0
    by_sections = math.ceil(section_count * cards_per_section)
    target = max(min_cards, min(max_cards, max(by_tokens, by_sections)))

    # 平均每单元至少 1 张，但不超过 max_cards
    if units:
        target = max(min(target, len(units) * 4), min(len(units), min_cards))

    meta = {
        **batch.meta,
        "unit_count": len(units),
        "section_count": section_count,
        "estimated_by_tokens": by_tokens,
        "estimated_by_sections": by_sections,
        "merge_under_tokens": merge_under,
    }

    return ChunkBatch(
        chunks=batch.chunks,
        units=units,
        total_tokens=total_tokens,
        target_card_count=target,
        meta=meta,
    )


def _parse_cards_json(raw: str) -> list[dict[str, Any]]:
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\[[\s\S]*\]", text)
        if not match:
            return []
        data = json.loads(match.group(0))
    if isinstance(data, dict) and "cards" in data:
        data = data["cards"]
    if not isinstance(data, list):
        return []
    items: list[dict[str, Any]] = []
    for index, row in enumerate(data):
        if not isinstance(row, dict):
            continue
        front = str(row.get("front") or row.get("question") or "").strip()
        back = str(row.get("back") or row.get("answer") or "").strip()
        if not front or not back:
            continue
        item: dict[str, Any] = {
            "id": str(row.get("id") or f"card_{index + 1}"),
            "front": front,
            "back": back,
            "tags": row.get("tags") if isinstance(row.get("tags"), list) else [],
        }
        explanation = str(row.get("explanation") or "").strip()
        if explanation:
            item["explanation"] = explanation
        if row.get("source_unit_id"):
            item["source_unit_id"] = row["source_unit_id"]
        items.append(item)
    return items


def _heuristic_cards_from_unit(unit: ProcessedUnit, count: int) -> list[dict[str, Any]]:
    """Deterministic fallback when LLM is unavailable (tests / offline)."""
    sentences = [s.strip() for s in re.split(r"[。！？\n]+", unit.text) if len(s.strip()) >= 12]
    if not sentences:
        sentences = [unit.text[:180]]
    cards: list[dict[str, Any]] = []
    for index in range(min(count, len(sentences))):
        sentence = sentences[index]
        front = f"关于「{unit.heading_path}」：{sentence[:80]}… 的核心含义是什么？"
        back = sentence[:400]
        cards.append(
            {
                "id": f"{unit.unit_id}_{index + 1}",
                "front": front,
                "back": back,
                "tags": ["auto", unit.heading_path[:32]],
                "source_unit_id": unit.unit_id,
            }
        )
    return cards


def synthesize_flashcards(
    batch: ChunkBatch,
    params: dict[str, Any],
    *,
    user_id: int | None = None,
    use_llm: bool = True,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    units = batch.units
    if not units:
        return [], {"error": "no_units", "target_card_count": 0}

    target = int(params.get("target_card_count") or batch.target_card_count or 12)
    style = str(params.get("style", "qa"))
    max_per_unit = max(1, int(params.get("max_cards_per_unit", 3)))

    # 按单元 token 权重分配配额
    total_tokens = sum(u.token_count for u in units) or 1
    quotas: list[int] = []
    remaining = target
    for index, unit in enumerate(units):
        if index == len(units) - 1:
            quota = remaining
        else:
            share = max(1, round(target * (unit.token_count / total_tokens)))
            quota = min(share, max_per_unit, remaining)
        quotas.append(max(0, min(quota, max_per_unit)))
        remaining -= quotas[-1]
    if sum(quotas) < target and units:
        quotas[0] += min(target - sum(quotas), max_per_unit - quotas[0])

    all_items: list[dict[str, Any]] = []
    llm_calls = 0

    for unit, quota in zip(units, quotas):
        if quota <= 0:
            continue
        if use_llm:
            generated = _synthesize_unit_with_llm(unit, quota, style, user_id=user_id)
            llm_calls += 1
        else:
            generated = []
        if not generated:
            generated = _heuristic_cards_from_unit(unit, quota)
        all_items.extend(generated)

    # 去重 front、截断到 target
    seen: set[str] = set()
    deduped: list[dict[str, Any]] = []
    for item in all_items:
        key = item["front"].lower()[:120]
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)
        if len(deduped) >= target:
            break

    for index, item in enumerate(deduped):
        item["id"] = f"card_{index + 1}"

    meta = {
        "target_card_count": target,
        "actual_card_count": len(deduped),
        "unit_count": len(units),
        "llm_calls": llm_calls,
        "style": style,
    }
    return deduped, meta


def _synthesize_unit_with_llm(
    unit: ProcessedUnit,
    quota: int,
    style: str,
    *,
    user_id: int | None,
) -> list[dict[str, Any]]:
    style_hint = {
        "qa": "问答卡：front 是清晰问题，back 是简洁准确答案",
        "term_def": "术语卡：front 是术语或符号，back 是定义与要点",
        "cloze": "填空卡：front 含关键空缺，back 是完整表述",
    }.get(style, "问答卡")

    prompt = f"""你是学习闪卡出题助手。仅根据下方资料片段出题，不要编造资料中没有的内容。

章节：{unit.heading_path}
需要生成：{quota} 张闪卡
题型：{style_hint}

资料片段：
\"\"\"
{unit.text[:3500]}
\"\"\"

输出严格 JSON 数组，每项字段：
- front (string)
- back (string)
- explanation (string, 可选)
- tags (string[], 可选)

不要输出其它文字。"""

    try:
        from services.llm_service import LLMService

        raw = LLMService().chat(
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_tokens=min(1200, 200 * quota + 200),
            user_id=user_id,
            endpoint="mini_app_flashcards",
            track_token=True,
        )
        cards = _parse_cards_json(raw)
        for card in cards:
            card["source_unit_id"] = unit.unit_id
            card.setdefault("tags", []).append(unit.heading_path[:24])
        return cards[:quota]
    except Exception as exc:
        logger.warning("LLM flashcard synthesis failed for %s: %s", unit.unit_id, exc)
        return []


def run_document_pipeline(
    user_id: int,
    subject_id: int,
    *,
    document_ids: list[int] | None = None,
    loader_params: dict[str, Any] | None = None,
    processor_params: dict[str, Any] | None = None,
    synthesizer_params: dict[str, Any] | None = None,
    use_llm: bool = True,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    loader_params = loader_params or {}
    processor_params = processor_params or {}
    synthesizer_params = synthesizer_params or {}

    batch = load_document_chunks(
        user_id,
        subject_id,
        document_ids=document_ids or loader_params.get("document_ids"),
        include_secondary=bool(loader_params.get("include_secondary", False)),
    )
    if not batch.chunks:
        return [], {"error": "no_chunks", "message": "未找到已解析完成的资料切块"}

    processed = process_chunk_batch(batch, processor_params)
    if synthesizer_params.get("target_card_count"):
        processed.target_card_count = int(synthesizer_params["target_card_count"])
    synthesizer_params.setdefault("target_card_count", processed.target_card_count)
    items, synth_meta = synthesize_flashcards(
        processed,
        synthesizer_params or {},
        user_id=user_id,
        use_llm=use_llm,
    )

    meta = {
        "pipeline": [
            "document_source_loader",
            "chunk_batch_processor",
            "flashcard_synthesizer",
        ],
        "loader": batch.to_dict(),
        "processor": processed.to_dict(),
        "synthesizer": synth_meta,
    }
    return items, meta


def merge_generation_into_spec(
    spec: dict[str, Any],
    items: list[dict[str, Any]],
    meta: dict[str, Any],
) -> dict[str, Any]:
    import copy

    updated = copy.deepcopy(spec)
    content = updated.setdefault("content", {})
    content["items"] = items
    content["generation"] = {
        **(content.get("generation") or {}),
        "last_run": meta,
        "card_count": len(items),
    }
    scheduler = updated.setdefault("scheduler", {})
    daily = int(scheduler.get("new_items_per_day", 20))
    if items and daily > len(items):
        scheduler["new_items_per_day"] = max(5, min(20, len(items)))
    return updated
