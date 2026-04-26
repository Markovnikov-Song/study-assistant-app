/// 错题模型
// ── 安全类型转换工具函数 ──────────────────────────────────────────────────────
int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class Mistake {
  final int id;
  final int notebookId;
  final int? subjectId;
  final String? title;
  final String content;
  final String noteType;
  final String? mistakeStatus;
  
  // 扩展字段
  final String? nodeId;
  final String? questionText;
  final String? userAnswer;
  final String? correctAnswer;
  final String? mistakeCategory;
  final int? reviewCardId;
  final int masteryScore;
  final int reviewCount;
  final DateTime? lastReviewedAt;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  Mistake({
    required this.id,
    required this.notebookId,
    this.subjectId,
    this.title,
    required this.content,
    required this.noteType,
    this.mistakeStatus,
    this.nodeId,
    this.questionText,
    this.userAnswer,
    this.correctAnswer,
    this.mistakeCategory,
    this.reviewCardId,
    this.masteryScore = 0,
    this.reviewCount = 0,
    this.lastReviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Mistake.fromJson(Map<String, dynamic> json) {
    return Mistake(
      id: _toInt(json['id']),
      notebookId: _toInt(json['notebook_id']),
      subjectId: _toIntOrNull(json['subject_id']),
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      noteType: json['note_type'] as String? ?? 'mistake',
      mistakeStatus: json['mistake_status'] as String?,
      nodeId: json['node_id'] as String?,
      questionText: json['question_text'] as String?,
      userAnswer: json['user_answer'] as String?,
      correctAnswer: json['correct_answer'] as String?,
      mistakeCategory: json['mistake_category'] as String?,
      reviewCardId: _toIntOrNull(json['review_card_id']),
      masteryScore: _toInt(json['mastery_score']),
      reviewCount: _toInt(json['review_count']),
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPending => mistakeStatus == 'pending';
  bool get isReviewed => mistakeStatus == 'reviewed';
}

/// 复习队列项
class ReviewItem {
  final int id;
  final int? noteId;
  final String nodeId;
  final String? nodeTitle;
  final int? subjectId;
  final int masteryScore;
  final int difficulty;
  final DateTime nextReview;
  final int interval;
  final int repetitions;
  final bool isOverdue;

  ReviewItem({
    required this.id,
    this.noteId,
    required this.nodeId,
    this.nodeTitle,
    this.subjectId,
    this.masteryScore = 0,
    this.difficulty = 2,
    required this.nextReview,
    this.interval = 0,
    this.repetitions = 0,
    this.isOverdue = false,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: _toInt(json['id']),
      noteId: _toIntOrNull(json['note_id']),
      nodeId: json['node_id'] as String? ?? '',
      nodeTitle: json['node_title'] as String?,
      subjectId: _toIntOrNull(json['subject_id']),
      masteryScore: _toInt(json['mastery_score']),
      difficulty: _toInt(json['difficulty'], fallback: 2),
      nextReview: DateTime.parse(json['next_review'] as String),
      interval: _toInt(json['interval']),
      repetitions: _toInt(json['repetitions']),
      isOverdue: json['is_overdue'] as bool? ?? false,
    );
  }

  String get difficultyLabel {
    switch (difficulty) {
      case 1: return '简单';
      case 2: return '中等';
      case 3: return '困难';
      default: return '中等';
    }
  }
}

/// 复习队列
class ReviewQueue {
  final int totalCount;
  final int todayCount;
  final int overdueCount;
  final int overdueDays;
  final int masteredCount;
  final int todayDone;
  final double recallRate;
  final List<ReviewItem> items;

  ReviewQueue({
    required this.totalCount,
    required this.todayCount,
    required this.overdueCount,
    required this.overdueDays,
    required this.masteredCount,
    required this.todayDone,
    required this.recallRate,
    required this.items,
  });

  factory ReviewQueue.fromJson(Map<String, dynamic> json) {
    return ReviewQueue(
      totalCount: _toInt(json['total_count']),
      todayCount: _toInt(json['today_count']),
      overdueCount: _toInt(json['overdue_count']),
      overdueDays: _toInt(json['overdue_days']),
      masteredCount: _toInt(json['mastered_count']),
      todayDone: _toInt(json['today_done']),
      recallRate: (json['recall_rate'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List? ?? [])
          .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 学科掌握度
class SubjectMastery {
  final int subjectId;
  final String subjectName;
  final int totalCards;
  final int masteredCards;
  final double avgMastery;
  final double avgEaseFactor;

  SubjectMastery({
    required this.subjectId,
    required this.subjectName,
    this.totalCards = 0,
    this.masteredCards = 0,
    this.avgMastery = 0.0,
    this.avgEaseFactor = 2.5,
  });

  factory SubjectMastery.fromJson(Map<String, dynamic> json) {
    return SubjectMastery(
      subjectId: _toInt(json['subject_id']),
      subjectName: json['subject_name'] as String? ?? '',
      totalCards: _toInt(json['total_cards']),
      masteredCards: _toInt(json['mastered_cards']),
      avgMastery: (json['avg_mastery'] as num?)?.toDouble() ?? 0.0,
      avgEaseFactor: (json['avg_ease_factor'] as num?)?.toDouble() ?? 2.5,
    );
  }
}

/// 复盘提交结果
class ReviewSubmitResult {
  final int noteId;
  final String mistakeStatus;
  final Map<String, dynamic> sm2Result;
  final String message;

  ReviewSubmitResult({
    required this.noteId,
    required this.mistakeStatus,
    required this.sm2Result,
    required this.message,
  });

  factory ReviewSubmitResult.fromJson(Map<String, dynamic> json) {
    return ReviewSubmitResult(
      noteId: _toInt(json['note_id']),
      mistakeStatus: json['mistake_status'] as String? ?? '',
      sm2Result: json['sm2_result'] as Map<String, dynamic>? ?? {},
      message: json['message'] as String? ?? '',
    );
  }

  int get newInterval => _toInt(sm2Result['interval_days']);
  int get newMastery => _toInt(sm2Result['mastery_score']);
  double get newEase => (sm2Result['ease_factor'] as num?)?.toDouble() ?? 2.5;
}

/// 学习进度汇总
class LearningProgress {
  final int subjectId;
  final String subjectName;
  final int sessionCount;
  final int litNodes;
  final int totalNodes;
  final double overallProgress;
  final double readProgress;
  final double practiceProgress;
  final double masteryProgress;
  final ReviewStats reviewStats;

  LearningProgress({
    required this.subjectId,
    required this.subjectName,
    this.sessionCount = 0,
    this.litNodes = 0,
    this.totalNodes = 0,
    this.overallProgress = 0.0,
    this.readProgress = 0.0,
    this.practiceProgress = 0.0,
    this.masteryProgress = 0.0,
    required this.reviewStats,
  });

  factory LearningProgress.fromJson(Map<String, dynamic> json) {
    return LearningProgress(
      subjectId: _toInt(json['subject_id']),
      subjectName: json['subject_name'] as String? ?? '',
      sessionCount: _toInt(json['session_count']),
      litNodes: _toInt(json['lit_nodes']),
      totalNodes: _toInt(json['total_nodes']),
      overallProgress: (json['overall_progress'] as num?)?.toDouble() ?? 0.0,
      readProgress: (json['read_progress'] as num?)?.toDouble() ?? 0.0,
      practiceProgress: (json['practice_progress'] as num?)?.toDouble() ?? 0.0,
      masteryProgress: (json['mastery_progress'] as num?)?.toDouble() ?? 0.0,
      reviewStats: ReviewStats.fromJson(
        json['review_stats'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// 复习统计
class ReviewStats {
  final int totalCards;
  final int masteredCards;
  final double avgMastery;

  ReviewStats({
    this.totalCards = 0,
    this.masteredCards = 0,
    this.avgMastery = 0.0,
  });

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    return ReviewStats(
      totalCards: _toInt(json['total_cards']),
      masteredCards: _toInt(json['mastered_cards']),
      avgMastery: (json['avg_mastery'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
