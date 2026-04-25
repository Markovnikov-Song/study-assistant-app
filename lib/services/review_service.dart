import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/review.dart';

class ReviewService {
  final Dio _dio = DioClient.instance.dio;

  // ── 错题管理 ──────────────────────────────────────────────────────────────

  /// 获取错题列表
  Future<List<Mistake>> getMistakes({
    String? status,  // pending | reviewed
    int? subjectId,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (status != null) queryParams['status'] = status;
      if (subjectId != null) queryParams['subject_id'] = subjectId;

      final res = await _dio.get(
        ApiConstants.reviewMistakes,
        queryParameters: queryParams,
      );
      return (res.data as List)
          .map((e) => Mistake.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取单个错题详情
  Future<Mistake> getMistake(int noteId) async {
    try {
      final res = await _dio.get('${ApiConstants.reviewMistakes}/$noteId');
      return Mistake.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 从练习结果创建错题（自动查找/创建错题本）
  Future<Mistake> createMistakeFromPractice({
    int? subjectId,
    String? title,
    required String content,
    String? nodeId,
    String? questionText,
    String? userAnswer,
    String? correctAnswer,
    String? mistakeCategory,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.reviewMistakeFromPractice,
        data: {
          'subject_id': subjectId,
          'title': title,
          'content': content,
          'node_id': nodeId,
          'question_text': questionText,
          'user_answer': userAnswer,
          'correct_answer': correctAnswer,
          'mistake_category': mistakeCategory,
        },
      );
      return Mistake.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── 复盘 ──────────────────────────────────────────────────────────────────

  /// 提交复盘结果
  Future<ReviewSubmitResult> submitReview({
    required int noteId,
    required int quality,  // 0-3: 忘了/模糊/想起/巩固
    String? reviewContent,
    bool? practiceCorrect,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.reviewSubmit,
        data: {
          'note_id': noteId,
          'quality': quality,
          'review_content': reviewContent,
          'practice_correct': practiceCorrect,
        },
      );
      return ReviewSubmitResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── 复习队列 ─────────────────────────────────────────────────────────────

  /// 获取复习队列
  Future<ReviewQueue> getReviewQueue({int limit = 20}) async {
    try {
      final res = await _dio.get(
        ApiConstants.reviewQueue,
        queryParameters: {'limit': limit},
      );
      return ReviewQueue.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取各学科掌握度
  Future<List<SubjectMastery>> getSubjectMastery() async {
    try {
      final res = await _dio.get(ApiConstants.reviewSubjects);
      return (res.data as List)
          .map((e) => SubjectMastery.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 对复习卡片评分
  Future<Map<String, dynamic>> rateReviewCard({
    required int cardId,
    required int quality,  // 0-3
  }) async {
    try {
      final res = await _dio.post(
        '${ApiConstants.reviewCardRate}/$cardId/rate',
        data: {'quality': quality},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── 进度统计 ─────────────────────────────────────────────────────────────

  /// 获取学习进度汇总
  Future<List<LearningProgress>> getProgressSummary() async {
    try {
      final res = await _dio.get(ApiConstants.progressSummary);
      return (res.data as List)
          .map((e) => LearningProgress.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
