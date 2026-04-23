import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/calendar_models.dart';

/// 安全地将 Dio 返回的 data 转为 Map（防止 Dio 有时返回 String）
Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is String) return jsonDecode(data) as Map<String, dynamic>;
  return {};
}

/// 安全地将 Dio 返回的 data 转为 List
List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is List) return decoded;
  }
  return [];
}

class CalendarApiService {
  final Dio _dio = DioClient.instance.dio;
  static const _base = '/api/calendar';

  // ── Events ────────────────────────────────────────────────────────────────

  Future<CalendarEvent> createEvent(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/events', data: data);
      return CalendarEvent.fromJson(_asMap(res.data));
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
      final map = _asMap(res.data);
      final list = map['events'] as List? ?? _asList(res.data);
      return list.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TodayEventsResult> getTodayEvents() async {
    try {
      final res = await _dio.get('$_base/events/today');
      final data = _asMap(res.data);
      return TodayEventsResult(
        events: (_asList(data['events']))
            .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: TodayStats.fromJson(_asMap(data['stats'])),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CalendarEvent> updateEvent(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('$_base/events/$id', data: data);
      return CalendarEvent.fromJson(_asMap(res.data));
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
      return _asMap(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Routines ──────────────────────────────────────────────────────────────

  Future<CalendarRoutine> createRoutine(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('$_base/routines', data: data);
      return CalendarRoutine.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<CalendarRoutine>> getRoutines() async {
    try {
      final res = await _dio.get('$_base/routines');
      final map = _asMap(res.data);
      final list = map['routines'] as List? ?? [];
      return list.map((e) => CalendarRoutine.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CalendarRoutine> updateRoutine(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.patch('$_base/routines/$id', data: data);
      return CalendarRoutine.fromJson(_asMap(res.data));
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
      return StudySession.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<CalendarStats> getStats({String period = '7d'}) async {
    try {
      final res = await _dio.get('$_base/stats', queryParameters: {'period': period});
      return CalendarStats.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final calendarApiServiceProvider = Provider<CalendarApiService>((_) => CalendarApiService());
