import 'package:dio/dio.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/daily_task.dart';
import '../../../services/calendar_service.dart';
import '../models/study_plan_models.dart';

/// 学习计划 API 服务
class StudyPlannerApiService {
  final Dio _dio = DioClient.instance.dio;
  static const _base = '/api/study-planner';
  final CalendarService _calendarService = CalendarService.instance;

  /// 创建计划，触发后台规划。返回 {plan_id, status}
  Future<Map<String, dynamic>> createPlan({
    required List<int> subjectIds,
    required DateTime deadline,
    required int dailyMinutes,
    String name = '我的学习计划',
  }) async {
    try {
      final res = await _dio.post('$_base/plans', data: {
        'subject_ids': subjectIds,
        'deadline': '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')}',
        'daily_minutes': dailyMinutes,
        'name': name,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取当前 active 计划
  Future<StudyPlan?> getActivePlan() async {
    try {
      final res = await _dio.get('$_base/plans/active');
      return StudyPlan.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取今日 plan_items
  Future<List<PlanItem>> getTodayItems() async {
    try {
      final res = await _dio.get('$_base/plans/today');
      final data = res.data as Map<String, dynamic>;
      return (data['items'] as List?)
              ?.map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 更新 plan_item 状态（done / skipped）
  Future<void> updateItemStatus(
    int planId,
    int itemId,
    String status, {
    Map<String, dynamic>? completionResult,
  }) async {
    try {
      await _dio.patch(
        '$_base/plans/$planId/items/$itemId',
        data: {
          'status': status,
          'completion_result': completionResult ?? const {},
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 放弃计划
  Future<void> abandonPlan(int planId) async {
    try {
      await _dio.patch('$_base/plans/$planId/status', data: {'status': 'abandoned'});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取计划摘要
  Future<PlanSummary> getPlanSummary(int planId) async {
    try {
      final res = await _dio.get('$_base/plans/$planId/summary');
      return PlanSummary.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 轮询规划进度
  Future<Map<String, dynamic>> getPlanProgress(int planId) async {
    try {
      final res = await _dio.get('$_base/plans/$planId/progress');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 增量重规划（日历改动后调整剩余排课）
  Future<Map<String, dynamic>> deltaReplan() async {
    try {
      final res = await _dio.post('$_base/replan');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 确认并执行学习计划
  Future<Map<String, dynamic>> confirmPlan({
    required int planId,
  }) async {
    // 1. 调用后端确认接口
    final res = await _dio.post('$_base/plans/$planId/confirm');

    // 2. 同步到日历
    final data = res.data as Map<String, dynamic>;
    if (data['calendar_synced'] == true) {
      // 获取任务列表并写入日历
      final tasks = (data['daily_tasks'] as List?)
              ?.map((e) => DailyTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      if (tasks.isNotEmpty) {
        // 确保日历服务已初始化
        await _calendarService.init();

        await _calendarService.importPlanToCalendar(
          planId: planId,
          tasks: tasks,
        );

        // 设置提醒
        await _calendarService.scheduleStudyReminders(
          planId: planId,
          startDate: DateTime.parse(tasks.first.date),
          endDate: DateTime.parse(tasks.last.date),
        );
      }
    }

    return data;
  }

  /// 更新任务状态
  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      await _dio.put('$_base/tasks/$taskId/status', data: {
        'status': status.name,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
