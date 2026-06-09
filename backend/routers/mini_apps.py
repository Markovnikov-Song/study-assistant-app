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
    MiniAppRollbackIn,
    MiniAppRollbackOut,
    MiniAppReviseIn,
    MiniAppReviseOut,
    MiniAppSaveIn,
    MiniAppSaveOut,
    MiniAppSummary,
    MiniAppVersion,
    MiniAppVersionDiffItem,
    MiniAppVersionDiffOut,
    MiniAppUpdateIn,
    MiniAppVersionListOut,
    MiniAppVersionOut,
    ValidateSpecIn,
    ValidateSpecOut,
    ValidateGraphIn,
    now_iso,
)
from mini_apps.store import (
    append_answer,
    append_run_event,
    create_app_version,
    create_run,
    create_session,
    delete_app,
    ensure_app_version,
    get_app,
    get_app_version,
    get_run,
    get_session,
    list_app_versions,
    list_apps,
    save_app,
)
from mini_apps.workflow import (
    WorkflowValidateIn,
    WorkflowValidateOut,
    WorkflowPatchIn,
    WorkflowPatchOut,
    get_workflow_blocks_registry,
    list_resource_actor_types,
    patch_workflow_definition,
    validate_workflow_definition,
)

router = APIRouter()


def _summary(app: MiniAppRecord) -> MiniAppSummary:
    return MiniAppSummary(
        id=app.id,
        title=app.title,
        app_type=app.app_type,
        subject_id=app.subject_id,
        status=app.status,
        current_version_id=app.current_version_id,
        description=summary_description(app),
        updated_at=app.updated_at,
        validation=app.validation,
    )


@router.get("", response_model=MiniAppListOut)
def list_mini_apps(user=Depends(get_current_user)):
    apps = [_summary(ensure_app_version(user["id"], app)) for app in list_apps(user["id"])]
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
    create_app_version(user["id"], app, source="create", summary="创建小工具初始版本")
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
    app = ensure_app_version(user["id"], app)

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
    create_app_version(user["id"], app, source="update", changed=_update_changed_fields(body))
    return MiniAppSaveOut(app=save_app(user["id"], app))


@router.post("/{app_id}/revise", response_model=MiniAppReviseOut)
def revise_mini_app(app_id: str, body: MiniAppReviseIn, user=Depends(get_current_user)):
    instruction = body.instruction.strip()
    if not instruction:
        raise HTTPException(400, "instruction cannot be empty")
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    app = ensure_app_version(user["id"], app)

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
    create_app_version(
        user["id"],
        app,
        source="revise",
        instruction=instruction,
        changed=changed,
        summary=f"助教改造：{instruction}",
    )
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


@router.get("/workflow/registry")
def list_workshop_workflow_registry(user=Depends(get_current_user)):
    return get_workflow_blocks_registry()


@router.get("/workflow/resource-actors")
def list_workshop_resource_actor_types(user=Depends(get_current_user)):
    return list_resource_actor_types()


@router.post("/workflow/validate", response_model=WorkflowValidateOut)
def validate_workshop_workflow(body: WorkflowValidateIn, user=Depends(get_current_user)):
    return validate_workflow_definition(body.workflow)


@router.post("/workflow/patch", response_model=WorkflowPatchOut)
def patch_workshop_workflow(body: WorkflowPatchIn, user=Depends(get_current_user)):
    instruction = body.instruction.strip()
    if not instruction:
        raise HTTPException(400, "instruction cannot be empty")
    return patch_workflow_definition(body.workflow, instruction)


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
    app = ensure_app_version(user["id"], app)

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
    create_app_version(
        user["id"],
        app,
        source="generate_cards",
        changed=["content.items", "runtime_config.json", "invisible_canvas.json"],
        summary=f"从资料生成 {len(items)} 张闪卡",
    )
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
    app = ensure_app_version(user["id"], app)
    graph = app.graph or materialize_graph(app.spec)[0]
    preview = execute_graph_preview(graph, app.spec)
    if not preview.get("ok"):
        raise HTTPException(400, "Mini app graph is not runnable")
    run = create_run(
        user["id"],
        app.id,
        graph,
        app_version_id=app.current_version_id,
        app_snapshot=_run_app_snapshot(app, graph),
    )
    return MiniAppRunStartOut(
        run_id=str(run["id"]),
        app_id=app.id,
        app_version_id=app.current_version_id,
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
    create_app_version(user["id"], draft, source="interview", summary="访谈生成小工具草稿")
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
    return ensure_app_version(user["id"], app)


@router.get("/{app_id}/versions", response_model=MiniAppVersionListOut)
def list_mini_app_versions(app_id: str, user=Depends(get_current_user)):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    app = ensure_app_version(user["id"], app)
    versions = list_app_versions(user["id"], app.id)
    return MiniAppVersionListOut(
        app_id=app.id,
        current_version_id=app.current_version_id,
        versions=versions,
        total=len(versions),
    )


@router.get("/{app_id}/versions/{version_id}", response_model=MiniAppVersionOut)
def get_mini_app_version(app_id: str, version_id: str, user=Depends(get_current_user)):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    app = ensure_app_version(user["id"], app)
    version = get_app_version(user["id"], app.id, version_id)
    if version is None:
        raise HTTPException(404, "Mini app version not found")
    return MiniAppVersionOut(version=version)


@router.get(
    "/{app_id}/versions/{version_id}/diff",
    response_model=MiniAppVersionDiffOut,
)
def diff_mini_app_version(
    app_id: str,
    version_id: str,
    user=Depends(get_current_user),
):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    app = ensure_app_version(user["id"], app)
    target = get_app_version(user["id"], app.id, version_id)
    if target is None:
        raise HTTPException(404, "Mini app version not found")
    return _version_diff(app, target)


@router.post(
    "/{app_id}/versions/{version_id}/rollback",
    response_model=MiniAppRollbackOut,
)
def rollback_mini_app_version(
    app_id: str,
    version_id: str,
    body: MiniAppRollbackIn,
    user=Depends(get_current_user),
):
    app = get_app(user["id"], app_id)
    if app is None:
        raise HTTPException(404, "Mini app not found")
    app = ensure_app_version(user["id"], app)
    target = get_app_version(user["id"], app.id, version_id)
    if target is None:
        raise HTTPException(404, "Mini app version not found")

    diff = _version_diff(app, target)
    restored = _restore_app_from_version(app, target)
    version = create_app_version(
        user["id"],
        restored,
        source="rollback",
        instruction=(body.reason or "").strip() or f"rollback to {target.id}",
        changed=diff.changed,
        summary=f"回滚到版本 {target.id}",
    )
    saved = save_app(user["id"], restored)
    return MiniAppRollbackOut(app=saved, version=version, diff=diff)


def _update_changed_fields(body: MiniAppUpdateIn) -> list[str]:
    changed: list[str] = []
    if body.title is not None:
        changed.append("title")
    if body.documents is not None:
        changed.extend(f"documents.{key}" for key in body.documents.keys())
    if body.spec is not None:
        changed.append("spec")
    if body.status is not None:
        changed.append("status")
    return changed


def _version_diff(
    app: MiniAppRecord,
    target: MiniAppVersion,
) -> MiniAppVersionDiffOut:
    current_snapshot = app.model_dump(mode="json")
    items = _diff_values("", current_snapshot, target.snapshot)
    changed = sorted({_top_level_path(item.path) for item in items if item.path})
    return MiniAppVersionDiffOut(
        app_id=app.id,
        base_version_id=app.current_version_id,
        target_version_id=target.id,
        items=items,
        changed=changed,
        total=len(items),
    )


def _restore_app_from_version(
    app: MiniAppRecord,
    target: MiniAppVersion,
) -> MiniAppRecord:
    snapshot = target.snapshot
    spec = dict(snapshot.get("spec") or {})
    graph, graph_validation = materialize_graph(spec)
    validation = merge_validations(validate_spec(spec), graph_validation)
    app.title = str(snapshot.get("title") or app.title)
    app.app_type = str(snapshot.get("app_type") or app.app_type)
    app.subject_id = snapshot.get("subject_id")
    app.status = "validated" if validation.ok else "draft"
    app.documents = dict(snapshot.get("documents") or {})
    app.spec = spec
    app.graph = graph
    app.validation = validation
    app.updated_at = now_iso()
    return app


def _diff_values(path: str, before, after) -> list[MiniAppVersionDiffItem]:
    if before == after:
        return []
    if isinstance(before, dict) and isinstance(after, dict):
        return _diff_dicts(path, before, after)
    if isinstance(before, list) and isinstance(after, list):
        return _diff_lists(path, before, after)
    return [
        MiniAppVersionDiffItem(
            path=path or "$",
            change_type="changed",
            before=before,
            after=after,
        )
    ]


def _diff_dicts(
    path: str,
    before: dict,
    after: dict,
) -> list[MiniAppVersionDiffItem]:
    items: list[MiniAppVersionDiffItem] = []
    keys = sorted(set(before.keys()) | set(after.keys()))
    for key in keys:
        next_path = f"{path}.{key}" if path else str(key)
        if key not in before:
            items.append(
                MiniAppVersionDiffItem(
                    path=next_path,
                    change_type="added",
                    after=after[key],
                )
            )
        elif key not in after:
            items.append(
                MiniAppVersionDiffItem(
                    path=next_path,
                    change_type="removed",
                    before=before[key],
                )
            )
        else:
            items.extend(_diff_values(next_path, before[key], after[key]))
    return items


def _diff_lists(
    path: str,
    before: list,
    after: list,
) -> list[MiniAppVersionDiffItem]:
    items: list[MiniAppVersionDiffItem] = []
    shared = min(len(before), len(after))
    for index in range(shared):
        items.extend(_diff_values(f"{path}[{index}]", before[index], after[index]))
    for index in range(shared, len(before)):
        items.append(
            MiniAppVersionDiffItem(
                path=f"{path}[{index}]",
                change_type="removed",
                before=before[index],
            )
        )
    for index in range(shared, len(after)):
        items.append(
            MiniAppVersionDiffItem(
                path=f"{path}[{index}]",
                change_type="added",
                after=after[index],
            )
        )
    return items


def _top_level_path(path: str) -> str:
    return path.split(".", 1)[0].split("[", 1)[0]


def _run_app_snapshot(app: MiniAppRecord, graph: dict[str, object]) -> dict[str, object]:
    return {
        "id": app.id,
        "title": app.title,
        "app_type": app.app_type,
        "subject_id": app.subject_id,
        "status": app.status,
        "version_id": app.current_version_id,
        "spec": app.spec,
        "graph": graph,
        "validation": app.validation.model_dump(mode="json"),
    }
