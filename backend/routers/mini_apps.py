from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException

from deps import get_current_user
from mini_apps.canvas import (
    execute_graph_preview,
    get_block_registry,
    materialize_graph,
    merge_validations,
    validate_graph,
)
from mini_apps.builder import (
    build_app_from_session,
    build_documents,
    build_quality_documents,
    next_question,
    revise_spec,
    summary_description,
    validate_spec,
)
from mini_apps.content_pipeline import (
    merge_generation_into_spec,
    run_document_pipeline,
)
from mini_apps.canvas import uses_document_pipeline
from mini_apps.models import (
    GenerateCardsForAppIn,
    GenerateCardsForAppOut,
    GenerateCardsIn,
    GenerateCardsOut,
    InterviewAnswerIn,
    InterviewStartIn,
    InterviewTurnOut,
    MiniAppListOut,
    MiniAppRecord,
    MiniAppRunEventIn,
    MiniAppRunEventOut,
    MiniAppRunOut,
    MiniAppRunStartOut,
    MiniAppReviseIn,
    MiniAppReviseOut,
    MiniAppSaveIn,
    MiniAppSaveOut,
    MiniAppSummary,
    MiniAppUpdateIn,
    ValidateSpecIn,
    ValidateSpecOut,
    ValidateGraphIn,
    now_iso,
)
from mini_apps.store import (
    append_answer,
    append_run_event,
    create_run,
    create_session,
    delete_app,
    get_app,
    get_run,
    get_session,
    list_apps,
    save_app,
)

router = APIRouter()


def _summary(app: MiniAppRecord) -> MiniAppSummary:
    return MiniAppSummary(
        id=app.id,
        title=app.title,
        app_type=app.app_type,
        subject_id=app.subject_id,
        status=app.status,
        description=summary_description(app),
        updated_at=app.updated_at,
        validation=app.validation,
    )


@router.get("", response_model=MiniAppListOut)
def list_mini_apps(user=Depends(get_current_user)):
    apps = [_summary(app) for app in list_apps(user["id"])]
    return MiniAppListOut(apps=apps, total=len(apps))


@router.post("", response_model=MiniAppSaveOut)
def save_mini_app(body: MiniAppSaveIn, user=Depends(get_current_user)):
    graph, graph_validation = materialize_graph(body.spec)
    validation = merge_validations(validate_spec(body.spec), graph_validation)
    created = now_iso()
    app = MiniAppRecord(
        id=f"mini_{abs(hash((user['id'], body.title, created))) & 0xffffffff:x}",
        user_id=str(user["id"]),
        title=body.title.strip(),
        app_type=body.app_type,
        subject_id=body.subject_id,
        status="validated" if validation.ok and body.status != "published" else body.status,
        documents=body.documents,
        spec=body.spec,
        graph=graph,
        validation=validation,
        created_at=created,
        updated_at=created,
    )
    return MiniAppSaveOut(app=save_app(user["id"], app))


@router.delete("/{app_id}", status_code=204)
def delete_mini_app(app_id: str, user=Depends(get_current_user)):
    if not delete_app(user["id"], app_id):
        raise HTTPException(404, "Mini app not found")


@router.put("/{app_id}", response_model=MiniAppSaveOut)
def update_mini_app(app_id: str, body: MiniAppUpdateIn, user=Depends(get_current_user)):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")

    spec = body.spec if body.spec is not None else app.spec
    graph, graph_validation = materialize_graph(spec)
    validation = merge_validations(validate_spec(spec), graph_validation)
    documents = dict(app.documents)
    if body.documents is not None:
        documents.update(body.documents)

    app.title = (body.title or app.title).strip()
    app.app_type = str((spec.get("app") or {}).get("type") or app.app_type)
    app.subject_id = (spec.get("app") or {}).get("subject_id", app.subject_id)
    app.spec = spec
    app.graph = graph
    app.documents = documents
    app.validation = validation
    app.status = body.status or ("validated" if validation.ok else "draft")
    app.updated_at = now_iso()
    return MiniAppSaveOut(app=save_app(user["id"], app))


@router.post("/{app_id}/revise", response_model=MiniAppReviseOut)
def revise_mini_app(app_id: str, body: MiniAppReviseIn, user=Depends(get_current_user)):
    instruction = body.instruction.strip()
    if not instruction:
        raise HTTPException(400, "instruction cannot be empty")
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")

    spec, changed = revise_spec(app.spec, instruction)
    graph, graph_validation = materialize_graph(spec)
    validation = merge_validations(validate_spec(spec), graph_validation)
    documents = build_documents(spec, [f"修订要求：{instruction}"])
    documents.update(build_quality_documents(spec))
    previous_log = app.documents.get("修订记录.md", "# 修订记录\n")
    documents["修订记录.md"] = (
        previous_log.rstrip()
        + f"\n\n- {now_iso()}：{instruction}\n  - 修改：{', '.join(changed) if changed else '未识别到可自动修改的字段'}\n"
    )

    app.title = str((spec.get("app") or {}).get("title") or app.title)
    app.app_type = str((spec.get("app") or {}).get("type") or app.app_type)
    app.subject_id = (spec.get("app") or {}).get("subject_id", app.subject_id)
    app.spec = spec
    app.graph = graph
    app.documents = documents
    app.validation = validation
    app.status = "validated" if validation.ok else "draft"
    app.updated_at = now_iso()
    saved = save_app(user["id"], app)
    return MiniAppReviseOut(app=saved, changed=changed)


@router.post("/validate", response_model=ValidateSpecOut)
def validate_mini_app_spec(body: ValidateSpecIn, user=Depends(get_current_user)):
    graph, graph_validation = materialize_graph(body.spec)
    validation = merge_validations(validate_spec(body.spec), graph_validation)
    return ValidateSpecOut(validation=validation, graph=graph)


@router.get("/blocks")
def list_mini_app_blocks(user=Depends(get_current_user)):
    return get_block_registry().as_dict()


@router.post("/generate-cards", response_model=GenerateCardsOut)
def generate_cards_from_documents(body: GenerateCardsIn, user=Depends(get_current_user)):
    spec = body.spec or {}
    content = spec.get("content") or {}
    generation = content.get("generation") or {}
    processor_params = {
        "merge_under_tokens": int(generation.get("merge_under_tokens", 120)),
        "max_units": int(generation.get("max_units", 48)),
        "min_unit_tokens": int(generation.get("min_unit_tokens", 40)),
        "cards_per_1000_tokens": float(generation.get("cards_per_1000_tokens", 4.0)),
        "cards_per_section": float(generation.get("cards_per_section", 2.0)),
        "min_cards": int(generation.get("min_cards", 8)),
        "max_cards": int(generation.get("max_cards", 120)),
    }
    synthesizer_params = {
        "style": str(generation.get("style", "qa")),
        "max_cards_per_unit": int(generation.get("max_cards_per_unit", 3)),
    }
    items, meta = run_document_pipeline(
        int(user["id"]),
        body.subject_id,
        document_ids=body.document_ids or None,
        processor_params=processor_params,
        synthesizer_params=synthesizer_params,
        use_llm=body.use_llm,
    )
    if not items:
        message = meta.get("message") or meta.get("error") or "未能生成闪卡"
        raise HTTPException(400, message)
    target = int(meta.get("synthesizer", {}).get("target_card_count", len(items)))
    return GenerateCardsOut(
        items=items,
        meta=meta,
        target_card_count=target,
        actual_card_count=len(items),
    )


@router.post("/{app_id}/generate-cards", response_model=GenerateCardsForAppOut)
def generate_cards_for_app(
    app_id: str,
    body: GenerateCardsForAppIn,
    user=Depends(get_current_user),
):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")

    spec = dict(app.spec)
    content = spec.setdefault("content", {})
    if not uses_document_pipeline(spec):
        content["source_type"] = "document"
        source = content.get("source") if isinstance(content.get("source"), dict) else {}
        content["source"] = {
            "subject_id": source.get("subject_id") or app.subject_id,
            "document_ids": body.document_ids or source.get("document_ids") or [],
            "include_secondary": bool(source.get("include_secondary", False)),
        }
        content.setdefault(
            "pipeline",
            ["document_source_loader", "chunk_batch_processor", "flashcard_synthesizer"],
        )
        content.setdefault("generation", {})

    source = content.get("source") if isinstance(content.get("source"), dict) else {}
    subject_id = source.get("subject_id") or app.subject_id
    if not subject_id:
        raise HTTPException(400, "缺少 subject_id，无法从资料生成闪卡")

    generation = content.get("generation") or {}
    processor_params = {
        "merge_under_tokens": int(generation.get("merge_under_tokens", 120)),
        "max_units": int(generation.get("max_units", 48)),
        "min_unit_tokens": int(generation.get("min_unit_tokens", 40)),
        "cards_per_1000_tokens": float(generation.get("cards_per_1000_tokens", 4.0)),
        "cards_per_section": float(generation.get("cards_per_section", 2.0)),
        "min_cards": int(generation.get("min_cards", 8)),
        "max_cards": int(generation.get("max_cards", 120)),
    }
    synthesizer_params = {
        "style": str(generation.get("style", "qa")),
        "max_cards_per_unit": int(generation.get("max_cards_per_unit", 3)),
    }
    document_ids = body.document_ids or source.get("document_ids") or None
    items, meta = run_document_pipeline(
        int(user["id"]),
        int(subject_id),
        document_ids=document_ids,
        processor_params=processor_params,
        synthesizer_params=synthesizer_params,
        use_llm=body.use_llm,
    )
    if not items:
        message = meta.get("message") or meta.get("error") or "未能生成闪卡"
        raise HTTPException(400, message)

    spec = merge_generation_into_spec(spec, items, meta)
    graph, graph_validation = materialize_graph(spec)
    validation = merge_validations(validate_spec(spec), graph_validation)
    documents = dict(app.documents)
    documents["runtime_config.json"] = json.dumps(spec, ensure_ascii=False, indent=2)
    documents["invisible_canvas.json"] = json.dumps(graph, ensure_ascii=False, indent=2)

    app.spec = spec
    app.graph = graph
    app.validation = validation
    app.documents = documents
    app.updated_at = now_iso()
    saved = save_app(user["id"], app)
    target = int(meta.get("synthesizer", {}).get("target_card_count", len(items)))
    return GenerateCardsForAppOut(
        app=saved,
        items=items,
        meta=meta,
        target_card_count=target,
        actual_card_count=len(items),
    )


@router.post("/graph/validate")
def validate_mini_app_graph(body: ValidateGraphIn, user=Depends(get_current_user)):
    return validate_graph(body.graph, body.spec)


@router.get("/{app_id}/graph")
def get_mini_app_graph(app_id: str, user=Depends(get_current_user)):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    graph = app.graph or materialize_graph(app.spec)[0]
    return {
        "app_id": app.id,
        "graph": graph,
        "validation": materialize_graph(app.spec)[1],
    }


@router.post("/{app_id}/graph/preview")
def preview_mini_app_graph(app_id: str, user=Depends(get_current_user)):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    graph = app.graph or materialize_graph(app.spec)[0]
    return execute_graph_preview(graph, app.spec)


@router.post("/{app_id}/runs/start", response_model=MiniAppRunStartOut)
def start_mini_app_run(app_id: str, user=Depends(get_current_user)):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    graph = app.graph or materialize_graph(app.spec)[0]
    preview = execute_graph_preview(graph, app.spec)
    if not preview.get("ok"):
        raise HTTPException(400, "Mini app graph is not runnable")
    run = create_run(user["id"], app.id, graph)
    return MiniAppRunStartOut(
        run_id=str(run["id"]),
        app_id=app.id,
        status=str(run["status"]),
        graph=graph,
        preview=preview,
        created_at=str(run["created_at"]),
    )


@router.get("/runs/{run_id}", response_model=MiniAppRunOut)
def get_mini_app_run(run_id: str, user=Depends(get_current_user)):
    run = get_run(run_id)
    if run is None or str(run.get("user_id")) != str(user["id"]):
        raise HTTPException(404, "Run not found")
    return MiniAppRunOut(run=run)


@router.post("/runs/{run_id}/events", response_model=MiniAppRunEventOut)
def append_mini_app_run_event(
    run_id: str,
    body: MiniAppRunEventIn,
    user=Depends(get_current_user),
):
    if not body.node_id.strip() or not body.event_type.strip():
        raise HTTPException(400, "node_id and event_type are required")
    result = append_run_event(
        user["id"],
        run_id,
        body.node_id.strip(),
        body.event_type.strip(),
        body.payload,
    )
    if result is None:
        raise HTTPException(404, "Run not found")
    run, event = result
    return MiniAppRunEventOut(
        run_id=run_id,
        event=event,
        event_count=len(run.get("events") or []),
    )


@router.post("/interview/start", response_model=InterviewTurnOut)
def start_interview(body: InterviewStartIn, user=Depends(get_current_user)):
    text = body.initial_request.strip()
    if not text:
        raise HTTPException(400, "initial_request cannot be empty")
    session = create_session(user["id"], text, body.subject_id)
    return InterviewTurnOut(
        session_id=session["id"],
        status="collecting",
        question=next_question(0),
        collected={"需求": text},
    )


@router.post("/interview/{session_id}/answer", response_model=InterviewTurnOut)
def answer_interview(session_id: str, body: InterviewAnswerIn, user=Depends(get_current_user)):
    answer = body.answer.strip()
    if not answer:
        raise HTTPException(400, "answer cannot be empty")
    session = append_answer(session_id, answer)
    if session is None or str(session.get("user_id")) != str(user["id"]):
        raise HTTPException(404, "Interview session not found")

    answers = session.get("answers", [])
    question = next_question(len(answers))
    collected = {"需求": str(session.get("initial_request") or "")}
    labels = ["内容", "练法", "反馈与复习"]
    for index, item in enumerate(answers):
        label = labels[index] if index < len(labels) else f"补充 {index + 1}"
        collected[label] = str(item)

    if question is not None:
        return InterviewTurnOut(
            session_id=session_id,
            status="collecting",
            question=question,
            collected=collected,
        )

    draft = build_app_from_session(user["id"], session)
    draft = save_app(user["id"], draft)
    return InterviewTurnOut(
        session_id=session_id,
        status="ready",
        collected=collected,
        draft=draft,
        validation=draft.validation,
    )


@router.get("/{app_id}", response_model=MiniAppRecord)
def get_mini_app(app_id: str, user=Depends(get_current_user)):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    return app
