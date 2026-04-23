import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/calendar_models.dart';

/// Calendar API 服务，封装所有 /api/calendar 端点调用
class CalendarApiService {
  final Dio _dio = DioClient.instance.dio;

  static const _base = '/api/calendar';

  // ─── 事件端点 ─────────────────────────────────────────────

  Future<List<CalendarEvent>> getEvents({
    required DateTime startDate,
    required DateTime endDate,
    int? subjectId,
    bool? isCompleted,
  }) async {
    try {
      final params = <String, dynamic>{
        'start_date': _fmtDate(startDate),
        'end_date': _fmtDate(endDate),
        if (subjectId != null) 'subject_id': subjectId,
        if (isCompleted != null) 'is_completed': isCompleted,
      };
      final res = await _dio.get('$_base/events', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      return (data['events'] as List)
          .map((e) => CalendarEvent.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TodayEventsResult> getTodayEvents() async {
    try {
      final res = await _dio.get('$_base/events/today');
      return TodayEventsResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CalendarEvent> createEvent(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/events', data: data);
      return CalendarEvent.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CalendarEvent> updateEvent(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('$_base/events/$id', data: data);
      return CalendarEvent.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteEvent(int id) async {
    try {
      await _dio.delete('$_base/events/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> batchCreateEvents(
      List<Map<String, dynamic>> events) async {
    try {
      final res = await _dio.post('$_base/events/batch', data: {'events': events});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 例程端点 ─────────────────────────────────────────────

  Future<List<CalendarRoutine>> getRoutines() async {
    try {
      final res = await _dio.get('$_base/routines');
      return (res.data as List)
          .map((e) => CalendarRoutine.fromJson(e))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CalendarRoutine> createRoutine(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/routines', data: data);
      return CalendarRoutine.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CalendarRoutine> updateRoutine(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('$_base/routines/$id', data: data);
      return CalendarRoutine.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteRoutine(int id) async {
    try {
      await _dio.delete('$_base/routines/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── Session 端点 ─────────────────────────────────────────

  Future<StudySession> createSession(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/sessions', data: data);
      return StudySession.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 统计端点 ─────────────────────────────────────────────

  Future<CalendarStats> getStats({required String period}) async {
    try {
      final res = await _dio.get('$_base/stats', queryParameters: {'period': period});
      return CalendarStats.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 工具方法 ─────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Riverpod Provider
final calendarApiServiceProvider = Provider<CalendarApiService>(
  (_) => CalendarApiService(),
);
