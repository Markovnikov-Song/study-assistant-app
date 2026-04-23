import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/calendar_models.dart';

class CalendarApiService {
  final Dio _dio = DioClient.instance.dio;
  static const _base = '/api/calendar';

  // ── Events ────────────────────────────────────────────────────────────────

  Future<CalendarEvent> createEvent(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/events', data: data);
      return CalendarEvent.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CalendarEvent>> getEvents({
    required String startDate,
    required String endDate,
    int? subjectId,
    bool? isCompleted,
  }) async {
    try {
      final params = <String, dynamic>{
        'start_date': startDate,
        'end_date': endDate,
        if (subjectId != null) 'subject_id': subjectId,
        if (isCompleted != null) 'is_completed': isCompleted,
      };
      final res = await _dio.get('$_base/events', queryParameters: params);
      final list = (res.data['events'] as List);
      return list.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TodayEventsResult> getTodayEvents() async {
    try {
      final res = await _dio.get('$_base/events/today');
      final data = res.data as Map<String, dynamic>;
      return TodayEventsResult(
        events: (data['events'] as List)
            .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: TodayStats.fromJson(data['stats'] as Map<String, dynamic>),
      );
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

  Future<Map<String, dynamic>> batchCreateEvents(List<Map<String, dynamic>> events) async {
    try {
      final res = await _dio.post('$_base/events/batch', data: {'events': events});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Routines ──────────────────────────────────────────────────────────────

  Future<CalendarRoutine> createRoutine(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/routines', data: data);
      return CalendarRoutine.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CalendarRoutine>> getRoutines() async {
    try {
      final res = await _dio.get('$_base/routines');
      return (res.data['routines'] as List)
          .map((e) => CalendarRoutine.fromJson(e as Map<String, dynamic>))
          .toList();
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

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<StudySession> createStudySession(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/sessions', data: data);
      return StudySession.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<CalendarStats> getStats({String period = '7d'}) async {
    try {
      final res = await _dio.get('$_base/stats', queryParameters: {'period': period});
      return CalendarStats.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final calendarApiServiceProvider = Provider<CalendarApiService>((_) => CalendarApiService());
