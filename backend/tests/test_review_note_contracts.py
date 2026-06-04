from contextlib import contextmanager
from datetime import datetime
from types import SimpleNamespace
import asyncio

from database import Note
from routers.notes import NoteCreateItem
from routers import quiz, review
from routers.review import MistakeCreateIn


def test_from_practice_mistake_payload_can_omit_notebook_id():
    payload = MistakeCreateIn(content="解题解析", title="解题错题")

    assert payload.notebook_id is None
    assert payload.content == "解题解析"


def test_note_create_payload_accepts_title():
    payload = NoteCreateItem(
        notebook_id=1,
        role="assistant",
        original_content="解题步骤",
        title="解题记录",
    )

    assert payload.title == "解题记录"


def test_from_practice_with_subject_creates_review_card(monkeypatch):
    created = {}

    class FakeQuery:
        def filter(self, *_args, **_kwargs):
            return self

        def first(self):
            return SimpleNamespace(name="数学")

    class FakeDb:
        def query(self, *_args, **_kwargs):
            return FakeQuery()

        def add(self, obj):
            if isinstance(obj, Note):
                obj.id = 101
                obj.mastery_score = 0
                obj.review_count = 0
                obj.last_reviewed_at = None
                obj.created_at = datetime.now()
                obj.updated_at = datetime.now()
                created["note"] = obj

        def flush(self):
            pass

    @contextmanager
    def fake_session():
        yield FakeDb()

    def fake_create_card(
        db,
        user_id,
        subject_id,
        node_id,
        subject_name=None,
        node_title=None,
        difficulty=2,
    ):
        created["card_args"] = {
            "user_id": user_id,
            "subject_id": subject_id,
            "node_id": node_id,
            "subject_name": subject_name,
            "node_title": node_title,
        }
        return SimpleNamespace(id=202)

    monkeypatch.setattr(review, "get_session", fake_session)
    monkeypatch.setattr(
        review,
        "get_or_create_mistake_notebook",
        lambda _db, _user_id: SimpleNamespace(id=7),
    )
    monkeypatch.setattr(review.SM2Engine, "create_card", fake_create_card)

    result = review.create_mistake_from_practice(
        MistakeCreateIn(
            subject_id=3,
            title="解题错题",
            content="题目和解析",
            question_text="原题",
            mistake_category="complete",
        ),
        user={"id": 1},
    )

    assert result.notebook_id == 7
    assert result.subject_id == 3
    assert result.review_card_id == 202
    assert created["card_args"]["subject_id"] == 3
    assert created["card_args"]["node_id"] == "note_101"


def test_from_practice_review_card_appears_in_review_queue(monkeypatch):
    created = {}

    class FakeQuery:
        def filter(self, *_args, **_kwargs):
            return self

        def first(self):
            return SimpleNamespace(name="鏁板")

    class FakeDb:
        def query(self, *_args, **_kwargs):
            return FakeQuery()

        def add(self, obj):
            if isinstance(obj, Note):
                obj.id = 303
                obj.mastery_score = 0
                obj.review_count = 0
                obj.last_reviewed_at = None
                obj.created_at = datetime.now()
                obj.updated_at = datetime.now()
                created["note"] = obj

        def flush(self):
            pass

    @contextmanager
    def fake_session():
        yield FakeDb()

    def fake_create_card(
        db,
        user_id,
        subject_id,
        node_id,
        subject_name=None,
        node_title=None,
        difficulty=2,
    ):
        card = SimpleNamespace(
            id=404,
            source_note=created["note"],
            node_id=node_id,
            node_title=node_title,
            subject_id=subject_id,
            mastery_score=0,
            difficulty=difficulty,
            next_review=datetime.now(),
            interval=0,
            repetitions=0,
        )
        created["card"] = card
        return card

    class FakeReviewQueue:
        def __init__(self, _db):
            pass

        def get_review_stats(self, user_id):
            assert user_id == 1
            return {
                "total_cards": 1,
                "today_review": 1,
                "overdue_cards": 0,
                "overdue_days": 0,
                "mastered_cards": 0,
                "today_done": 0,
                "recall_rate": 0.0,
            }

        def get_today_review(self, user_id, limit=20):
            assert user_id == 1
            assert limit == 20
            return [created["card"]]

    monkeypatch.setattr(review, "get_session", fake_session)
    monkeypatch.setattr(
        review,
        "get_or_create_mistake_notebook",
        lambda _db, _user_id: SimpleNamespace(id=7),
    )
    monkeypatch.setattr(review.SM2Engine, "create_card", fake_create_card)
    monkeypatch.setattr(review, "ReviewQueue", FakeReviewQueue)

    mistake = review.create_mistake_from_practice(
        MistakeCreateIn(
            subject_id=3,
            title="瑙ｉ閿欓",
            content="棰樼洰鍜岃В鏋?",
            question_text="鍘熼",
            mistake_category="complete",
        ),
        user={"id": 1},
    )

    queue = review.get_review_queue(limit=20, user={"id": 1})

    assert mistake.review_card_id == 404
    assert queue.total_count == 1
    assert queue.today_count == 1
    assert len(queue.items) == 1
    assert queue.items[0]["note_id"] == 303
    assert queue.items[0]["subject_id"] == 3
    assert queue.items[0]["node_id"] == "note_303"


def test_quiz_wrong_answer_creates_mistake_and_review_card(monkeypatch):
    created = {}

    class FakeSubjectQuery:
        def filter_by(self, **kwargs):
            created["subject_filter"] = kwargs
            return self

        def first(self):
            return SimpleNamespace(name="数学")

    class FakeDb:
        def query(self, *_args, **_kwargs):
            return FakeSubjectQuery()

        def add(self, obj):
            if isinstance(obj, Note):
                obj.id = 505
                obj.mastery_score = 0
                obj.review_count = 0
                obj.last_reviewed_at = None
                obj.created_at = datetime.now()
                obj.updated_at = datetime.now()
                created["note"] = obj

        def flush(self):
            pass

    @contextmanager
    def fake_session():
        yield FakeDb()

    def fake_create_card(
        db,
        user_id,
        subject_id,
        node_id,
        subject_name=None,
        node_title=None,
        difficulty=2,
    ):
        created["card_args"] = {
            "user_id": user_id,
            "subject_id": subject_id,
            "node_id": node_id,
            "subject_name": subject_name,
            "node_title": node_title,
        }
        return SimpleNamespace(id=606)

    monkeypatch.setattr("database.get_session", fake_session)
    monkeypatch.setattr(
        review,
        "get_or_create_mistake_notebook",
        lambda _db, _user_id: SimpleNamespace(id=8),
    )
    monkeypatch.setattr(review.SM2Engine, "create_card", fake_create_card)

    result = asyncio.run(
        quiz.submit_answer(
            quiz.SubmitAnswerIn(
                question_id="q1",
                user_answer="B",
                correct_answer="A",
                question_type="choice",
                node_id="node-algebra",
                node_title="一元一次方程",
                question_text="x + 2 = 5, x = ?",
                subject_id=3,
            ),
            user={"id": 1},
        ),
    )

    assert result["correct"] is False
    assert result["added_to_mistake_book"] is True
    assert result["review_card_id"] == 606
    assert created["note"].notebook_id == 8
    assert created["note"].note_type == "mistake"
    assert created["note"].mistake_status == "pending"
    assert created["note"].node_id == "node-algebra"
    assert created["note"].user_answer == "B"
    assert created["note"].correct_answer == "A"
    assert created["note"].review_card_id == 606
    assert created["card_args"]["subject_id"] == 3
    assert created["card_args"]["node_id"] == "node-algebra"
    assert created["card_args"]["node_title"] == "一元一次方程"


def test_quiz_wrong_answer_does_not_claim_mistake_saved_on_failure(monkeypatch):
    @contextmanager
    def failing_session():
        raise RuntimeError("database unavailable")
        yield

    monkeypatch.setattr("database.get_session", failing_session)

    result = asyncio.run(
        quiz.submit_answer(
            quiz.SubmitAnswerIn(
                question_id="q2",
                user_answer="B",
                correct_answer="A",
                question_type="choice",
                node_id="node-algebra",
                node_title="一元一次方程",
                question_text="x + 2 = 5, x = ?",
                subject_id=3,
            ),
            user={"id": 1},
        ),
    )

    assert result["correct"] is False
    assert result["added_to_mistake_book"] is False
    assert result["review_card_id"] is None
