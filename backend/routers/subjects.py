from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from deps import get_current_user
from utils import (
    get_user_subjects, get_subject, create_subject,
    update_subject, delete_subject,
    toggle_pin_subject, toggle_archive_subject,
)

router = APIRouter()

class SubjectOut(BaseModel):
    id: int
    name: str
    category: Optional[str]
    description: Optional[str]
    is_pinned: bool
    is_archived: bool
    created_at: str

    @classmethod
    def from_dict(cls, d: dict):
        return cls(
            id=d["id"], name=d["name"],
            category=d.get("category"), description=d.get("description"),
            is_pinned=bool(d.get("is_pinned", False)),
            is_archived=bool(d.get("is_archived", False)),
            created_at=d["created_at"].isoformat(),
        )

class SubjectIn(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: Optional[str] = None
    description: Optional[str] = None

@router.get("", response_model=List[SubjectOut])
def list_subjects(include_archived: bool = False, user=Depends(get_current_user)):
    return [SubjectOut.from_dict(s) for s in get_user_subjects(user["id"], include_archived=include_archived)]

@router.post("", response_model=SubjectOut, status_code=201)
def create(body: SubjectIn, user=Depends(get_current_user)):
    r = create_subject(user["id"], body.name, body.category or "", body.description or "")
    if not r["success"]:
        raise HTTPException(400, r["error"])
    return SubjectOut.from_dict(r["subject"])

@router.get("/{subject_id}", response_model=SubjectOut)
def get_one(subject_id: int, user=Depends(get_current_user)):
    s = get_subject(subject_id, user["id"])
    if not s:
        raise HTTPException(404, "学科不存在")
    return SubjectOut.from_dict(s)

@router.put("/{subject_id}", response_model=SubjectOut)
def update(subject_id: int, body: SubjectIn, user=Depends(get_current_user)):
    r = update_subject(subject_id, user["id"], body.name, body.category or "", body.description or "")
    if not r["success"]:
        raise HTTPException(400, r["error"])
    return SubjectOut.from_dict(get_subject(subject_id, user["id"]))

@router.delete("/{subject_id}", status_code=204)
def delete(subject_id: int, user=Depends(get_current_user)):
    r = delete_subject(subject_id, user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])

@router.post("/{subject_id}/pin")
def pin(subject_id: int, user=Depends(get_current_user)):
    r = toggle_pin_subject(subject_id, user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])
    return r

@router.post("/{subject_id}/archive")
def archive(subject_id: int, user=Depends(get_current_user)):
    r = toggle_archive_subject(subject_id, user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])
    return r
