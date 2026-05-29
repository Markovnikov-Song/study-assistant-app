from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any

from database import Subject


@dataclass(frozen=True)
class ExamPrepDraft:
    goal: str
    subject_id: int | None
    subject_name: str | None
    deadline: str | None
    daily_minutes: int | None
    missing_slots: list[str]
    capability_mix: list[dict[str, Any]]
    suggested_widgets: list[str]


class ExamPrepOrchestrator:
    """Intake and draft planning for exam-prep goals."""

    known_subjects = [
        "材料力学",
        "理论力学",
        "高等数学",
        "线性代数",
        "概率论与数理统计",
        "大学物理",
        "大学英语",
        "数据结构",
        "计算机网络",
        "操作系统",
    ]

    def infer_subject_name(self, goal: str) -> str | None:
        for subject in self.known_subjects:
            if subject in goal:
                return subject
        patterns = [
            r"(?:备考|复习|学习|学|准备)\s*([\u4e00-\u9fa5A-Za-z0-9·]{2,24})",
            r"([\u4e00-\u9fa5A-Za-z0-9·]{2,24})(?:考试|期末|考研|复习|备考)",
        ]
        for pattern in patterns:
            match = re.search(pattern, goal)
            if not match:
                continue
            name = match.group(1).strip(" ，。,.!！?？")
            if name and name not in {"一个", "一下", "计划", "考试", "期末", "复习", "备考"}:
                return name[:128]
        return None

    def infer_deadline(self, goal: str) -> str | None:
        iso = re.search(r"(20\d{2})[-/年](\d{1,2})[-/月](\d{1,2})", goal)
        if iso:
            y, m, d = map(int, iso.groups())
            try:
                return date(y, m, d).isoformat()
            except ValueError:
                return None
        if "下周" in goal:
            return (date.today() + timedelta(days=7)).isoformat()
        if "两周" in goal or "2周" in goal:
            return (date.today() + timedelta(days=14)).isoformat()
        if "期末" in goal or "考试" in goal or "备考" in goal:
            return None
        return None

    def infer_daily_minutes(self, goal: str) -> int | None:
        hour = re.search(r"(\d+(?:\.\d+)?)\s*(?:小时|h|H)", goal)
        if hour:
            return max(15, min(480, round(float(hour.group(1)) * 60)))
        minute = re.search(r"(\d+)\s*(?:分钟|min)", goal)
        if minute:
            return max(15, min(480, int(minute.group(1))))
        return None

    def ensure_subject(self, db, user_id: int, goal: str) -> Subject | None:
        name = self.infer_subject_name(goal)
        if not name:
            return None
        subject = (
            db.query(Subject)
            .filter(Subject.user_id == user_id, Subject.name == name)
            .first()
        )
        if subject:
            return subject
        subject = Subject(
            user_id=user_id,
            name=name,
            category="exam_prep",
            description="由 ExamPrepOrchestrator 根据备考目标自动创建",
        )
        db.add(subject)
        db.flush()
        return subject

    def draft(self, db, user_id: int, goal: str) -> ExamPrepDraft:
        subject = self.ensure_subject(db, user_id, goal)
        deadline = self.infer_deadline(goal)
        daily_minutes = self.infer_daily_minutes(goal)
        missing = []
        if subject is None:
            missing.append("subject")
        if deadline is None:
            missing.append("deadline")
        if daily_minutes is None:
            missing.append("daily_minutes")
        return ExamPrepDraft(
            goal=goal,
            subject_id=subject.id if subject else None,
            subject_name=subject.name if subject else None,
            deadline=deadline,
            daily_minutes=daily_minutes,
            missing_slots=missing,
            capability_mix=[
                {"capability_id": "lecture.view", "label": "讲义学习", "weight": 0.30},
                {"capability_id": "quiz.generate", "label": "自动出题", "weight": 0.30},
                {
                    "capability_id": "memory.drill",
                    "label": "百词斩式概念/公式记忆",
                    "weight": 0.25,
                    "patterns": ["pattern.recognition_choice", "pattern.spaced_recall_card"],
                    "adapters": ["adapter.formula", "adapter.political_concept"],
                },
                {"capability_id": "review.center", "label": "SM-2 错题复盘", "weight": 0.15},
            ],
            suggested_widgets=[
                "MissingInfoCard",
                "KnowledgeMapPreview",
                "CapabilityMixCard",
                "SchedulePreviewCard",
            ],
        )
