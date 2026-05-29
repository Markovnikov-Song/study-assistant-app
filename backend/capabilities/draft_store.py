from __future__ import annotations

import json
import threading
from pathlib import Path

from .models import CapabilityDef

_STORE_PATH = Path(__file__).parent.parent / "data" / "capability_drafts.json"
_LOCK = threading.Lock()


def _read_all() -> dict[str, list[dict]]:
    if not _STORE_PATH.exists():
        return {}
    try:
        return json.loads(_STORE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _write_all(data: dict[str, list[dict]]) -> None:
    _STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    _STORE_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def list_user_drafts(user_id: int | str) -> list[CapabilityDef]:
    with _LOCK:
        data = _read_all()
        raw_drafts = data.get(str(user_id), [])
    drafts: list[CapabilityDef] = []
    for raw in raw_drafts:
        try:
            drafts.append(CapabilityDef(**raw))
        except Exception:
            continue
    return drafts


def save_user_draft(user_id: int | str, draft: CapabilityDef) -> CapabilityDef:
    with _LOCK:
        data = _read_all()
        key = str(user_id)
        drafts = data.setdefault(key, [])
        draft_data = draft.model_dump(mode="json")
        replaced = False
        for index, item in enumerate(drafts):
            if item.get("id") == draft.id:
                drafts[index] = draft_data
                replaced = True
                break
        if not replaced:
            drafts.append(draft_data)
        _write_all(data)
    return draft

