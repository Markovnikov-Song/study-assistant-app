import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import '../services/notification_service.dart';

/// 复盘服务 Provider
final reviewServiceProvider = Provider((ref) => ReviewService());

/// 错题列表 Provider
final mistakeListProvider = FutureProvider.family<List<Mistake>, MistakeFilter>(
  (ref, filter) async {
    final service = ref.read(reviewServiceProvider);
    return service.getMistakes(
      status: filter.status,
      subjectId: filter.subjectId,
      limit: filter.limit,
    );
  },
);

/// 错题筛选条件
class MistakeFilter {
  final String? status;
  final int? subjectId;
  final int limit;

  MistakeFilter({
    this.status,
    this.subjectId,
    this.limit = 50,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MistakeFilter &&
        other.status == status &&
        other.subjectId == subjectId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(status, subjectId, limit);
}

/// 待复盘错题 Provider
final pendingMistakesProvider = FutureProvider<List<Mistake>>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.getMistakes(status: 'pending');
});

/// 已复盘错题 Provider
final reviewedMistakesProvider = FutureProvider<List<Mistake>>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.getMistakes(status: 'reviewed');
});

/// 复习队列 Provider
final reviewQueueProvider = FutureProvider<ReviewQueue>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.getReviewQueue();
});

/// 学科掌握度 Provider
final subjectMasteryProvider = FutureProvider<List<SubjectMastery>>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.getSubjectMastery();
});

/// 学习进度汇总 Provider
final progressSummaryProvider = FutureProvider<List<LearningProgress>>((ref) async {
  final service = ref.read(reviewServiceProvider);
  return service.getProgressSummary();
});

/// 复习提醒服务 Provider
final reviewReminderServiceProvider = Provider<ReviewReminderService>((ref) {
  return ReviewReminderService();
});

/// 复习提醒服务：自动安排本地通知提醒
class ReviewReminderService {
  final _notificationService = NotificationService.instance;
  bool _isEnabled = true;

  /// 设置是否启用提醒
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// 根据复习队列安排提醒
  Future<void> scheduleFromQueue(ReviewQueue queue) async {
    if (!_isEnabled) return;

    // 取消旧提醒
    await _notificationService.cancelAllReminders();

    // 为每个待复习项安排提醒
    for (final item in queue.items) {
      if (item.nextReview.isAfter(DateTime.now())) {
        await _scheduleReminder(item);
      }
    }
  }

  /// 为单个复习项安排提醒
  Future<void> _scheduleReminder(ReviewItem item) async {
    final title = '复习提醒';
    final body = item.nodeTitle != null
        ? '「${item.nodeTitle}」该复习了'
        : '有知识点该复习了';

    // 使用 item.id 作为通知 ID（确保唯一性）
    await _notificationService.scheduleReviewReminder(
      id: item.id,
      title: title,
      body: body,
      scheduledTime: item.nextReview,
      payload: 'review:${item.id}',
    );
  }

  /// 手动安排提醒
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_isEnabled) return;

    await _notificationService.scheduleReviewReminder(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledTime,
    );
  }

  /// 取消提醒
  Future<void> cancelReminder(int id) async {
    await _notificationService.cancelReminder(id);
  }

  /// 取消所有提醒
  Future<void> cancelAll() async {
    await _notificationService.cancelAllReminders();
  }
}

/// 复盘状态管理
class ReviewNotifier extends StateNotifier<ReviewState> {
  final ReviewService _service;
  final Ref _ref;

  ReviewNotifier(this._service, this._ref) : super(const ReviewState());

  /// 创建错题
  Future<Mistake?> createMistakeFromPractice({
    int? subjectId,
    String? title,
    required String content,
    String? nodeId,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
    String? mistakeCategory,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final mistake = await _service.createMistakeFromPractice(
        subjectId: subjectId,
        title: title,
        content: content,
        nodeId: nodeId,
        questionText: questionText,
        userAnswer: userAnswer,
        correctAnswer: correctAnswer,
        mistakeCategory: mistakeCategory,
      );
      // 刷新错题列表
      _ref.invalidate(pendingMistakesProvider);
      _ref.invalidate(reviewedMistakesProvider);
      state = state.copyWith(isLoading: false);
      return mistake;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// 提交复盘
  Future<ReviewSubmitResult?> submitReview({
    required int noteId,
    required int quality,
    String? reviewContent,
    bool? practiceCorrect,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.submitReview(
        noteId: noteId,
        quality: quality,
        reviewContent: reviewContent,
        practiceCorrect: practiceCorrect,
      );
      // 刷新数据
      _ref.invalidate(pendingMistakesProvider);
      _ref.invalidate(reviewedMistakesProvider);
      _ref.invalidate(reviewQueueProvider);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// 对复习卡片评分
  Future<Map<String, dynamic>?> rateCard({
    required int cardId,
    required int quality,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.rateReviewCard(
        cardId: cardId,
        quality: quality,
      );
      _ref.invalidate(reviewQueueProvider);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

/// 复盘状态
class ReviewState {
  final bool isLoading;
  final String? error;

  const ReviewState({
    this.isLoading = false,
    this.error,
  });

  ReviewState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return ReviewState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 复盘状态 Provider
final reviewNotifierProvider =
    StateNotifierProvider<ReviewNotifier, ReviewState>((ref) {
  final service = ref.read(reviewServiceProvider);
  return ReviewNotifier(service, ref);
});
