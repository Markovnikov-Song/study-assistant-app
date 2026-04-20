import os
import threading
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel
from deps import get_current_user
from services.document_service import DocumentService
from backend_config import get_config

router = APIRouter()
_svc = DocumentService()

def _get_allowed() -> set[str]:
    return get_config().document_allowed_extensions_set


class DocOut(BaseModel):
    id: int
    filename: str
    status: str
    error: Optional[str]
    created_at: str

    @classmethod
    def from_dict(cls, d: dict):
        return cls(id=d["id"], filename=d["filename"], status=d["status"],
                   error=d.get("error"), created_at=d["created_at"].isoformat())


@router.get("", response_model=List[DocOut])
def list_docs(subject_id: int, user=Depends(get_current_user)):
    return [DocOut.from_dict(d) for d in _svc.list_documents(subject_id=subject_id, user_id=user["id"])]


@router.post("", status_code=202)
async def upload(file: UploadFile = File(...), subject_id: int = Form(...), user=Depends(get_current_user)):
    ext = os.path.splitext(file.filename)[1].lower()
    allowed = _get_allowed()
    if ext not in allowed:
        raise HTTPException(400, f"不支持的文件格式：{ext}，支持：{', '.join(sorted(allowed))}")
    # 重复文件名检测
    existing = _svc.list_documents(subject_id=subject_id, user_id=user["id"])
    if any(d["filename"] == file.filename for d in existing):
        raise HTTPException(409, f"文件「{file.filename}」已存在，请先删除旧文件或重命名后上传")

    file_bytes = await file.read()
    filename = file.filename

    # 先创建 pending 记录，立即返回 doc_id
    doc_id = _svc.create_pending(filename=filename, subject_id=subject_id, user_id=user["id"])

    # 后台线程异步处理
    def _process():
        _svc.process_existing(doc_id=doc_id, file_bytes=file_bytes,
                               filename=filename, subject_id=subject_id, user_id=user["id"])

    threading.Thread(target=_process, daemon=True).start()
    return {"doc_id": doc_id}


@router.delete("/{doc_id}", status_code=204)
def delete(doc_id: int, subject_id: int, user=Depends(get_current_user)):
    r = _svc.delete_document(doc_id=doc_id, subject_id=subject_id, user_id=user["id"])
    if not r["success"]:
        raise HTTPException(400, r["error"])


@router.post("/{doc_id}/reindex", status_code=202, summary="重新分块并向量化指定文档")
def reindex(doc_id: int, subject_id: int, user=Depends(get_current_user)):
    """
    删除旧向量和 chunk 记录，用新的分块策略重新处理文档。
    文档原始文件已不在服务器，需从数据库 Chunk 表重建文本后重新向量化。
    """
    from database import Chunk, Document, get_session as db_sess
    from services.embedding_service import EmbeddingService

    with db_sess() as db:
        doc = db.query(Document).filter_by(id=doc_id, user_id=user["id"]).first()
        if not doc:
            raise HTTPException(404, "文档不存在")
        # 读取现有 chunk 内容（原始文本）
        old_chunks = (db.query(Chunk).filter_by(document_id=doc_id)
                      .order_by(Chunk.chunk_index).all())
        full_text = "\n".join(c.content for c in old_chunks)
        filename = doc.filename

    if not full_text.strip():
        raise HTTPException(400, "文档内容为空，无法重新索引")

    def _reindex():
        try:
            # 删除旧向量
            _svc._delete_vectors(doc_id, subject_id)
            # 用新分块策略重新分块
            new_chunks = _svc.chunk_text(full_text)
            emb_svc = EmbeddingService()
            vectors = emb_svc.embed_texts(new_chunks)
            _svc._store_vectors(new_chunks, vectors, doc_id, subject_id, filename)
            # 更新 Chunk 表
            from database import Chunk, get_session as db_sess2
            with db_sess2() as db2:
                db2.query(Chunk).filter_by(document_id=doc_id).delete()
                for idx, content in enumerate(new_chunks):
                    db2.add(Chunk(document_id=doc_id, subject_id=subject_id,
                                  chunk_index=idx, content=content))
            _svc._update_doc_status(doc_id, "completed")
        except Exception as e:
            _svc._update_doc_status(doc_id, "failed", str(e))

    _svc._update_doc_status(doc_id, "processing")
    threading.Thread(target=_reindex, daemon=True).start()
    return {"doc_id": doc_id, "status": "reindexing"}


@router.post("/reindex-all", status_code=202, summary="重新索引某学科下所有文档")
def reindex_all(subject_id: int, user=Depends(get_current_user)):
    """对指定学科下所有 completed 状态的文档触发重新索引。"""
    docs = _svc.list_documents(subject_id=subject_id, user_id=user["id"])
    triggered = []
    for d in docs:
        if d["status"] == "completed":
            # 复用单文档重新索引逻辑（同步触发后台线程）
            from database import Chunk, Document, get_session as db_sess
            from services.embedding_service import EmbeddingService
            import threading as _t

            doc_id = d["id"]
            filename = d["filename"]

            with db_sess() as db:
                old_chunks = (db.query(Chunk).filter_by(document_id=doc_id)
                              .order_by(Chunk.chunk_index).all())
                full_text = "\n".join(c.content for c in old_chunks)

            if not full_text.strip():
                continue

            def _reindex(did=doc_id, fn=filename, txt=full_text):
                try:
                    _svc._delete_vectors(did, subject_id)
                    new_chunks = _svc.chunk_text(txt)
                    vectors = EmbeddingService().embed_texts(new_chunks)
                    _svc._store_vectors(new_chunks, vectors, did, subject_id, fn)
                    from database import Chunk, get_session as db2
                    with db2() as db:
                        db.query(Chunk).filter_by(document_id=did).delete()
                        for idx, content in enumerate(new_chunks):
                            db.add(Chunk(document_id=did, subject_id=subject_id,
                                         chunk_index=idx, content=content))
                    _svc._update_doc_status(did, "completed")
                except Exception as e:
                    _svc._update_doc_status(did, "failed", str(e))

            _svc._update_doc_status(doc_id, "processing")
            _t.Thread(target=_reindex, daemon=True).start()
            triggered.append(doc_id)

    return {"triggered": triggered, "count": len(triggered)}
