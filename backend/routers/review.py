"""
复盘 API：练习 → 错题本 → 复盘 → SM-2 完整闭环。

核心功能：
1. 练习结果自动添加错题本
2. 错题复盘引导流程
3. 复盘完成后创建 SM-2 复习卡片
4. 复习提醒与进度追踪
"""

from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import Note, Notebook, ReviewCard, ReviewLog, get_session
from deps import get_current_user
from services.sm2_engine import ReviewQueue, SM2Engine

router = APIRouter()


# ============================================================================
# Pydantic 模型
# ============================================================================

class MistakeCreateIn(BaseModel):
    """创建错题的请求"""
    notebook_id: int
    subject_id: Optional[int] = None
    title: Optional[str] = None
    content: str = Field(..., description="题目内容或错误描述")
    
    # 练习相关字段
    node_id: Optional[str] = None
    question_text: Optional[str] = None
    user_answer: Optional[str] = None
    correct_answer: Optional[str] = None
    mistake_category: Optional[str] = Field(
        None, 
        description="错因分类: concept(概念模糊) | calculation(计算错误) | careless(粗心) | complete(完全不会)"
    )
    
    # 关联的 SM-2 卡片（如果有的话）
    review_card_id: Optional[int] = None


class MistakeOut(BaseModel):
    """错题输出"""
    id: int
    notebook_id: int
    subject_id: Optional[int]
    title: Optional[str]
    content: str
    note_type: str
    mistake_status: Optional[str]
    
    # 扩展字段
    node_id: Optional[str]
    question_text: Optional[str]
    user_answer: Optional[str]
    correct_answer: Optional[str]
    mistake_category: Optional[str]
    review_card_id: Optional[int]
    mastery_score: int
    review_count: int
    last_reviewed_at: Optional[str]
    
    created_at: str
    updated_at: str

    @classmethod
    def from_orm(cls, note: Note) -> "MistakeOut":
        return cls(
            id=note.id,
            notebook_id=note.notebook_id,
            subject_id=note.subject_id,
            title=note.title,
            content=note.original_content,
            note_type=note.note_type,
            mistake_status=note.mistake_status,
            node_id=note.node_id,
            question_text=note.question_text,
            user_answer=note.user_answer,
            correct_answer=note.correct_answer,
            mistake_category=note.mistake_category,
            review_card_id=note.review_card_id,
            mastery_score=note.mastery_score,
            review_count=note.review_count,
            last_reviewed_at=note.last_reviewed_at.isoformat() if note.last_reviewed_at else None,
            created_at=note.created_at.isoformat(),
            updated_at=note.updated_at.isoformat(),
        )


class ReviewSubmitIn(BaseModel):
    """提交复盘结果的请求"""
    note_id: int
    quality: int = Field(..., ge=0, le=3, description="评分 0-3: 忘了/模糊/想起/巩固")
    
    # 复盘内容（可选，用于更新笔记）
    review_content: Optional[str] = None
    
    # 类似题目练习结果
    practice_correct: Optional[bool] = None


class ReviewSubmitOut(BaseModel):
    """复盘结果输出"""
    note_id: int
    mistake_status: str
    
    # SM-2 结果
    sm2_result: Dict[str, Any]
    
    message: str


class ReviewQueueOut(BaseModel):
    """复习队列输出"""
    total_count: int
    today_count: int
    overdue_count: int
    overdue_days: int
    mastered_count: int
    today_done: int
    recall_rate: float
    
    items: List[Dict[str, Any]]


class SubjectMasteryOut(BaseModel):
    """学科掌握度输出"""
    subject_id: int
    subject_name: str
    total_cards: int
    mastered_cards: int
    avg_mastery: float
    avg_ease_factor: float


# ============================================================================
# 辅助函数
# ============================================================================

def get_or_create_mistake_notebook(db: Session, user_id: int) -> Notebook:
    """获取或创建用户的错题本"""
    notebook = db.query(Notebook).filter(
        Notebook.user_id == user_id,
        Notebook.is_system == 1,
        Notebook.name == "错题本"
    ).first()
    
    if not notebook:
        notebook = Notebook(
            user_id=user_id,
            name="错题本",
            is_system=1,
            is_pinned=1,
        )
        db.add(notebook)
        db.flush()
    
    return notebook


# ============================================================================
# 错题管理 API
# ============================================================================

@router.get("/mistakes", response_model=List[MistakeOut])
def list_mistakes(
    status: Optional[str] = None,  # pending | reviewed
    subject_id: Optional[int] = None,
    limit: int = 50,
    user=Depends(get_current_user),
):
    """
    获取用户的错题列表。
    
    支持按状态和学科筛选。
    """
    with get_session() as db:
        query = db.query(Note).filter(
            Note.notebook_id.in_(
                db.query(Notebook.id).filter(Notebook.user_id == user["id"])
            ),
            Note.note_type == "mistake"
        )
        
        if status:
            query = query.filter(Note.mistake_status == status)
        if subject_id:
            query = query.filter(Note.subject_id == subject_id)
        
        notes = query.order_by(Note.created_at.desc()).limit(limit).all()
        
        return [MistakeOut.from_orm(n) for n in notes]


@router.get("/mistakes/{note_id}", response_model=MistakeOut)
def get_mistake(
    note_id: int,
    user=Depends(get_current_user),
):
    """获取单个错题详情"""
    with get_session() as db:
        note = db.query(Note).join(Notebook).filter(
            Note.id == note_id,
            Notebook.user_id == user["id"],
            Note.note_type == "mistake"
        ).first()
        
        if not note:
            raise HTTPException(404, "错题不存在")
        
        return MistakeOut.from_orm(note)


@router.post("/mistakes", response_model=MistakeOut, status_code=201)
def create_mistake(
    body: MistakeCreateIn,
    user=Depends(get_current_user),
):
    """
    创建新的错题记录。
    
    通常在练习完成后自动调用，正确答题不会创建错题。
    """
    with get_session() as db:
        # 验证笔记本存在
        notebook = db.query(Notebook).filter(
            Notebook.id == body.notebook_id,
            Notebook.user_id == user["id"]
        ).first()
        
        if not notebook:
            raise HTTPException(404, "笔记本不存在")
        
        # 创建错题笔记
        note = Note(
            notebook_id=body.notebook_id,
            subject_id=body.subject_id,
            title=body.title,
            original_content=body.content,
            role="user",
            note_type="mistake",
            mistake_status="pending",
            node_id=body.node_id,
            question_text=body.question_text,
            user_answer=body.user_answer,
            correct_answer=body.correct_answer,
            mistake_category=body.mistake_category,
            review_card_id=body.review_card_id,
        )
        
        db.add(note)
        db.flush()
        
        return MistakeOut.from_orm(note)


@router.post("/mistakes/from-practice", response_model=MistakeOut, status_code=201)
def create_mistake_from_practice(
    body: MistakeCreateIn,
    user=Depends(get_current_user),
):
    """
    从练习结果自动创建错题。
    
    自动查找或创建错题本，并创建关联的 SM-2 复习卡片。
    """
    with get_session() as db:
        # 自动获取/创建错题本
        notebook = get_or_create_mistake_notebook(db, user["id"])
        
        # 创建错题笔记
        note = Note(
            notebook_id=notebook.id,
            subject_id=body.subject_id,
            title=body.title or "练习错题",
            original_content=body.content,
            role="user",
            note_type="mistake",
            mistake_status="pending",
            node_id=body.node_id,
            question_text=body.question_text,
            user_answer=body.user_answer,
            correct_answer=body.correct_answer,
            mistake_category=body.mistake_category,
        )
        
        db.add(note)
        db.flush()
        
        # 如果提供了 node_id 或 subject_id，自动创建 SM-2 复习卡片
        if body.node_id or body.subject_id:
            subject_name = None
            if body.subject_id:
                from database import Subject
                subject = db.query(Subject).filter(Subject.id == body.subject_id).first()
                if subject:
                    subject_name = subject.name
            
            review_card = SM2Engine.create_card(
                db,
                user_id=user["id"],
                subject_id=body.subject_id or 0,
                node_id=body.node_id or f"note_{note.id}",
                subject_name=subject_name,
                node_title=body.title,
            )
            
            # 关联错题和复习卡片
            note.review_card_id = review_card.id
        
        db.flush()
        return MistakeOut.from_orm(note)


# ============================================================================
# 复盘 API
# ============================================================================

@router.post("/review/submit", response_model=ReviewSubmitOut)
def submit_review(
    body: ReviewSubmitIn,
    user=Depends(get_current_user),
):
    """
    提交复盘结果。
    
    完成以下操作：
    1. 更新错题状态为 'reviewed'
    2. 更新笔记内容（复盘分析）
    3. 如果有 SM-2 卡片，计算下次复习时间
    4. 同步掌握度到 Note 表
    """
    with get_session() as db:
        # 获取错题
        note = db.query(Note).join(Notebook).filter(
            Note.id == body.note_id,
            Notebook.user_id == user["id"],
            Note.note_type == "mistake"
        ).first()
        
        if not note:
            raise HTTPException(404, "错题不存在")
        
        # 更新笔记内容
        if body.review_content:
            note.original_content = note.original_content + "\n\n---\n\n**复盘分析：**\n" + body.review_content
        
        # 更新复盘状态
        note.mistake_status = "reviewed"
        note.review_count += 1
        note.last_reviewed_at = datetime.now()
        
        sm2_result = None
        message = "复盘完成"
        
        # 如果有关联的 SM-2 卡片，计算下次复习
        if note.review_card_id:
            review_card = db.query(ReviewCard).filter(
                ReviewCard.id == note.review_card_id
            ).first()
            
            if review_card:
                sm2_result = SM2Engine.calculate_next_review(
                    db, review_card, quality=body.quality
                )
                
                # 同步掌握度
                note.mastery_score = sm2_result.get("mastery_score", 0)
                
                # 记录掌握度历史
                history = note.mastery_history or []
                history.append({
                    "date": datetime.now().isoformat(),
                    "score": sm2_result.get("mastery_score", 0),
                    "quality": body.quality,
                    "interval_days": sm2_result.get("interval_days", 0),
                })
                note.mastery_history = history
        
        # 如果没有关联卡片，但有 node_id，也创建 SM-2 卡片
        elif note.node_id and note.subject_id:
            subject_name = None
            from database import Subject
            subject = db.query(Subject).filter(Subject.id == note.subject_id).first()
            if subject:
                subject_name = subject.name
            
            review_card = SM2Engine.create_card(
                db,
                user_id=user["id"],
                subject_id=note.subject_id,
                node_id=note.node_id,
                subject_name=subject_name,
                node_title=note.title,
            )
            
            note.review_card_id = review_card.id
            
            sm2_result = SM2Engine.calculate_next_review(
                db, review_card, quality=body.quality
            )
            note.mastery_score = sm2_result.get("mastery_score", 0)
        
        return ReviewSubmitOut(
            note_id=note.id,
            mistake_status=note.mistake_status,
            sm2_result=sm2_result or {},
            message=message,
        )


# ============================================================================
# 复习队列 API
# ============================================================================

@router.get("/review/queue", response_model=ReviewQueueOut)
def get_review_queue(
    limit: int = 20,
    user=Depends(get_current_user),
):
    """
    获取复习队列。
    
    包含今日待复习、过期卡片、已掌握等信息。
    """
    with get_session() as db:
        queue = ReviewQueue(db)
        
        # 获取统计数据
        stats = queue.get_review_stats(user["id"])
        
        # 获取今日复习项
        today_cards = queue.get_today_review(user["id"], limit=limit)
        
        items = []
        for card in today_cards:
            items.append({
                "id": card.id,
                "note_id": card.source_note.id if card.source_note else None,
                "node_id": card.node_id,
                "node_title": card.node_title,
                "subject_id": card.subject_id,
                "mastery_score": card.mastery_score,
                "difficulty": card.difficulty,
                "next_review": card.next_review.isoformat(),
                "interval": card.interval,
                "repetitions": card.repetitions,
                "is_overdue": card.next_review < datetime.now(),
            })
        
        return ReviewQueueOut(
            total_count=stats["total_cards"],
            today_count=stats["today_review"],
            overdue_count=stats["overdue_cards"],
            overdue_days=stats["overdue_days"],
            mastered_count=stats["mastered_cards"],
            today_done=stats["today_done"],
            recall_rate=stats["recall_rate"],
            items=items,
        )


@router.get("/review/subjects", response_model=List[SubjectMasteryOut])
def get_subject_mastery(
    user=Depends(get_current_user),
):
    """获取各学科的掌握度统计"""
    with get_session() as db:
        queue = ReviewQueue(db)
        mastery_data = queue.get_subject_mastery(user["id"])
        return [SubjectMasteryOut(**m) for m in mastery_data]


@router.post("/review/card/{card_id}/rate")
def rate_review_card(
    card_id: int,
    quality: int = Query(..., ge=0, le=3),
    user=Depends(get_current_user),
):
    """
    对复习卡片进行评分。
    
    这是在复习流程中调用的 API，计算下次复习时间。
    """
    with get_session() as db:
        card = db.query(ReviewCard).filter(
            ReviewCard.id == card_id,
            ReviewCard.user_id == user["id"]
        ).first()
        
        if not card:
            raise HTTPException(404, "复习卡片不存在")
        
        result = SM2Engine.calculate_next_review(db, card, quality=quality)
        
        # 如果卡片关联了 Note，同步掌握度
        if card.source_note:
            card.source_note.mastery_score = result.get("mastery_score", 0)
            card.source_note.review_count += 1
            card.source_note.last_reviewed_at = datetime.now()
        
        return result


# ============================================================================
# 进度统计 API
# ============================================================================

@router.get("/progress/summary")
def get_progress_summary(
    user=Depends(get_current_user),
):
    """
    获取学习进度汇总。
    
    整合阅读进度、练习进度、掌握进度。
    """
    with get_session() as db:
        from database import Subject, MindmapNodeState, ConversationSession
        
        # 获取用户学科
        subjects = db.query(Subject).filter(
            Subject.user_id == user["id"],
            Subject.is_archived == 0
        ).all()
        
        result = []
        for subject in subjects:
            # 获取会话数
            session_count = db.query(ConversationSession).filter(
                ConversationSession.subject_id == subject.id
            ).count()
            
            # 获取点亮节点数
            lit_nodes = db.query(MindmapNodeState).filter(
                MindmapNodeState.user_id == user["id"],
                MindmapNodeState.is_lit == 1,
                MindmapNodeState.session_id.in_(
                    db.query(ConversationSession.id).filter(
                        ConversationSession.subject_id == subject.id
                    )
                )
            ).count()
            
            # 获取总叶子节点数：从最新思维导图 session 的 content 解析
            from routers.library import _parse_leaf_node_ids
            latest_mindmap = db.query(ConversationSession).filter(
                ConversationSession.subject_id == subject.id,
                ConversationSession.user_id == user["id"],
                ConversationSession.session_type == "mindmap",
            ).order_by(ConversationSession.created_at.desc()).first()

            leaf_texts = set()
            if latest_mindmap:
                from sqlalchemy import text as sa_text
                row = db.execute(
                    sa_text("SELECT content FROM conversation_sessions WHERE id = :sid"),
                    {"sid": latest_mindmap.id},
                ).fetchone()
                if row and row[0]:
                    leaf_texts = _parse_leaf_node_ids(row[0])

            total_leaves = len(leaf_texts)

            # 获取复习统计
            queue = ReviewQueue(db)
            mastery_data = queue.get_subject_mastery(user["id"])
            subject_mastery = next(
                (m for m in mastery_data if m["subject_id"] == subject.id),
                None
            )
            total_cards = subject_mastery["total_cards"] if subject_mastery else 0

            if total_leaves == 0:
                total_leaves = max(total_cards, lit_nodes, 1)

            # 讲义节点数（已生成讲义的叶子节点）
            from database import NodeLecture
            subject_session_ids = [
                r[0] for r in db.query(ConversationSession.id).filter(
                    ConversationSession.subject_id == subject.id,
                    ConversationSession.user_id == user["id"],
                ).all()
            ]
            lecture_node_ids = set()
            if subject_session_ids:
                lecture_node_ids = {
                    r.node_id for r in db.query(NodeLecture.node_id).filter(
                        NodeLecture.user_id == user["id"],
                        NodeLecture.session_id.in_(subject_session_ids),
                    ).all()
                }
            lecture_leaves = len(lecture_node_ids & leaf_texts) if leaf_texts else len(lecture_node_ids)

            # 练习节点数（已做过练习的叶子节点）
            from database import ReviewCard
            practiced_node_ids = set()
            if subject_session_ids:
                practiced_node_ids = {
                    r.node_id for r in db.query(ReviewCard.node_id).filter(
                        ReviewCard.user_id == user["id"],
                        ReviewCard.subject_id == subject.id,
                        ReviewCard.total_reviews > 0,
                    ).all()
                }
            practiced_leaves = len(practiced_node_ids & leaf_texts) if leaf_texts else len(practiced_node_ids)

            # 进度计算：讲义占50%，练习占50%
            lecture_progress = lecture_leaves / total_leaves if total_leaves > 0 else 0.0
            practice_progress = practiced_leaves / total_leaves if total_leaves > 0 else 0.0
            overall_progress = min(lecture_progress * 0.5 + practice_progress * 0.5, 1.0)
            read_progress = lit_nodes / total_leaves if total_leaves > 0 else 0.0
            mastery_progress = subject_mastery["avg_mastery"] / 5.0 if subject_mastery else 0.0
            
            result.append({
                "subject_id": subject.id,
                "subject_name": subject.name,
                "session_count": session_count,
                "lit_nodes": lit_nodes,
                "total_nodes": total_leaves,
                "overall_progress": round(overall_progress, 2),
                "read_progress": round(read_progress, 2),
                "practice_progress": round(practice_progress, 2),
                "mastery_progress": round(mastery_progress, 2),
                "review_stats": {
                    "total_cards": subject_mastery["total_cards"] if subject_mastery else 0,
                    "mastered_cards": subject_mastery["mastered_cards"] if subject_mastery else 0,
                    "avg_mastery": subject_mastery["avg_mastery"] if subject_mastery else 0,
                }
            })
        
        return result
