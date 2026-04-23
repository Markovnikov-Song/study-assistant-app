// Preservation Property Tests
//
// These tests verify that well-formed JSON still parses correctly on UNFIXED code.
// They MUST PASS before the fix is applied — this establishes the baseline behavior
// that the fix must preserve.
//
// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5

import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/features/calendar/models/calendar_models.dart';

// ---------------------------------------------------------------------------
// Helpers — generate well-formed JSON inputs
// ---------------------------------------------------------------------------

/// Builds a valid CalendarStats JSON with [n] daily_stats entries and
/// [m] subject_stats entries. All numeric fields are ints (not Strings).
Map<String, dynamic> _buildCalendarStatsJson({
  required int totalDurationMinutes,
  required int checkinDays,
  required int streakDays,
  required List<Map<String, dynamic>> dailyStats,
  required List<Map<String, dynamic>> subjectStats,
}) {
  return {
    'period': '7d',
    'total_duration_minutes': totalDurationMinutes,
    'checkin_days': checkinDays,
    'streak_days': streakDays,
    'daily_stats': dailyStats,
    'subject_stats': subjectStats,
  };
}

Map<String, dynamic> _dailyStatEntry(String date, int durationMinutes) => {
      'date': date,
      'duration_minutes': durationMinutes,
    };

Map<String, dynamic> _subjectStatEntry({
  required int subjectId,
  required String subjectName,
  required String color,
  required int durationMinutes,
  required double percentage,
}) =>
    {
      'subject_id': subjectId,
      'subject_name': subjectName,
      'color': color,
      'duration_minutes': durationMinutes,
      'percentage': percentage,
    };

Map<String, dynamic> _buildRoutineJson({
  required int id,
  required int durationMinutes,
  int? dayOfWeek,
  int? subjectId,
}) =>
    {
      'id': id,
      'title': 'Morning Study',
      'repeat_type': 'weekly',
      'day_of_week': dayOfWeek,
      'start_time': '08:00',
      'duration_minutes': durationMinutes,
      'subject_id': subjectId,
      'color': '#6366F1',
      'start_date': '2025-01-01',
      'is_active': true,
      'created_at': '2025-01-01T00:00:00',
    };

Map<String, dynamic> _buildStudySessionJson({
  required int id,
  required int durationMinutes,
  required int pomodoroCount,
  int? eventId,
  int? subjectId,
}) =>
    {
      'id': id,
      'event_id': eventId,
      'subject_id': subjectId,
      'started_at': '2025-01-01T08:00:00',
      'ended_at': '2025-01-01T09:00:00',
      'duration_minutes': durationMinutes,
      'pomodoro_count': pomodoroCount,
      'created_at': '2025-01-01T00:00:00',
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── CalendarStats preservation ──────────────────────────────────────────

  group('Preservation — CalendarStats.fromJson with well-formed JSON', () {
    test('dailyStats.length equals input list length', () {
      // Property: for any well-formed CalendarStats JSON, the parsed
      // dailyStats list has the same length as the input daily_stats list.
      final testCases = [
        <Map<String, dynamic>>[],
        [_dailyStatEntry('2025-01-01', 60)],
        [
          _dailyStatEntry('2025-01-01', 30),
          _dailyStatEntry('2025-01-02', 90),
          _dailyStatEntry('2025-01-03', 45),
        ],
        List.generate(
          7,
          (i) => _dailyStatEntry(
            '2025-01-${(i + 1).toString().padLeft(2, '0')}',
            (i + 1) * 10,
          ),
        ),
      ];

      for (final dailyList in testCases) {
        final json = _buildCalendarStatsJson(
          totalDurationMinutes: 120,
          checkinDays: dailyList.length,
          streakDays: 1,
          dailyStats: dailyList,
          subjectStats: [],
        );

        final result = CalendarStats.fromJson(json);

        expect(
          result.dailyStats.length,
          equals(dailyList.length),
          reason:
              'dailyStats.length should equal input list length (${dailyList.length})',
        );
      }
    });

    test('all dailyStats field values match input', () {
      final dailyList = [
        _dailyStatEntry('2025-03-10', 45),
        _dailyStatEntry('2025-03-11', 120),
        _dailyStatEntry('2025-03-12', 30),
      ];

      final json = _buildCalendarStatsJson(
        totalDurationMinutes: 195,
        checkinDays: 3,
        streakDays: 3,
        dailyStats: dailyList,
        subjectStats: [],
      );

      final result = CalendarStats.fromJson(json);

      expect(result.totalDurationMinutes, equals(195));
      expect(result.checkinDays, equals(3));
      expect(result.streakDays, equals(3));

      for (var i = 0; i < dailyList.length; i++) {
        expect(
          result.dailyStats[i].durationMinutes,
          equals(dailyList[i]['duration_minutes'] as int),
          reason: 'dailyStats[$i].durationMinutes should match input',
        );
      }
    });

    test('subjectStats.length equals input list length', () {
      final subjectList = [
        _subjectStatEntry(
          subjectId: 1,
          subjectName: 'Math',
          color: '#FF0000',
          durationMinutes: 60,
          percentage: 50.0,
        ),
        _subjectStatEntry(
          subjectId: 2,
          subjectName: 'Physics',
          color: '#00FF00',
          durationMinutes: 60,
          percentage: 50.0,
        ),
      ];

      final json = _buildCalendarStatsJson(
        totalDurationMinutes: 120,
        checkinDays: 2,
        streakDays: 1,
        dailyStats: [],
        subjectStats: subjectList,
      );

      final result = CalendarStats.fromJson(json);

      expect(result.subjectStats.length, equals(subjectList.length));
      expect(result.subjectStats[0].subjectName, equals('Math'));
      expect(result.subjectStats[0].durationMinutes, equals(60));
      expect(result.subjectStats[1].subjectName, equals('Physics'));
    });

    // Property sweep: varying list sizes with all-int numerics
    test('property sweep — dailyStats.length preserved across multiple sizes', () {
      for (var n = 0; n <= 10; n++) {
        final dailyList = List.generate(
          n,
          (i) => _dailyStatEntry(
            '2025-01-${(i + 1).toString().padLeft(2, '0')}',
            i * 15,
          ),
        );

        final json = _buildCalendarStatsJson(
          totalDurationMinutes: n * 15,
          checkinDays: n,
          streakDays: n > 0 ? 1 : 0,
          dailyStats: dailyList,
          subjectStats: [],
        );

        final result = CalendarStats.fromJson(json);

        expect(
          result.dailyStats.length,
          equals(n),
          reason: 'For n=$n daily items, dailyStats.length should be $n',
        );
      }
    });
  });

  // ── CalendarRoutine preservation ─────────────────────────────────────────

  group('Preservation — CalendarRoutine.fromJson with valid int fields', () {
    test('id, durationMinutes, dayOfWeek, subjectId equal input values', () {
      final json = _buildRoutineJson(
        id: 7,
        durationMinutes: 45,
        dayOfWeek: 3,
        subjectId: 12,
      );

      final result = CalendarRoutine.fromJson(json);

      expect(result.id, equals(7));
      expect(result.durationMinutes, equals(45));
      expect(result.dayOfWeek, equals(3));
      expect(result.subjectId, equals(12));
    });

    test('nullable fields are null when absent', () {
      final json = _buildRoutineJson(
        id: 1,
        durationMinutes: 60,
        dayOfWeek: null,
        subjectId: null,
      );

      final result = CalendarRoutine.fromJson(json);

      expect(result.id, equals(1));
      expect(result.durationMinutes, equals(60));
      expect(result.dayOfWeek, isNull);
      expect(result.subjectId, isNull);
    });

    // Property sweep: varying int values for id, durationMinutes, dayOfWeek, subjectId
    test('property sweep — numeric fields preserved across many int values', () {
      final testCases = [
        (id: 1, dur: 30, dow: 1, sid: 5),
        (id: 42, dur: 60, dow: 5, sid: 99),
        (id: 100, dur: 90, dow: 7, sid: 1),
        (id: 999, dur: 120, dow: 2, sid: 50),
        (id: 0, dur: 15, dow: 6, sid: 3),
      ];

      for (final tc in testCases) {
        final json = _buildRoutineJson(
          id: tc.id,
          durationMinutes: tc.dur,
          dayOfWeek: tc.dow,
          subjectId: tc.sid,
        );

        final result = CalendarRoutine.fromJson(json);

        expect(result.id, equals(tc.id),
            reason: 'id should equal ${tc.id}');
        expect(result.durationMinutes, equals(tc.dur),
            reason: 'durationMinutes should equal ${tc.dur}');
        expect(result.dayOfWeek, equals(tc.dow),
            reason: 'dayOfWeek should equal ${tc.dow}');
        expect(result.subjectId, equals(tc.sid),
            reason: 'subjectId should equal ${tc.sid}');
      }
    });
  });

  // ── StudySession preservation ─────────────────────────────────────────────

  group('Preservation — StudySession.fromJson with valid int fields', () {
    test('all numeric fields equal input values', () {
      final json = _buildStudySessionJson(
        id: 5,
        durationMinutes: 50,
        pomodoroCount: 2,
        eventId: 10,
        subjectId: 3,
      );

      final result = StudySession.fromJson(json);

      expect(result.id, equals(5));
      expect(result.durationMinutes, equals(50));
      expect(result.pomodoroCount, equals(2));
      expect(result.eventId, equals(10));
      expect(result.subjectId, equals(3));
    });

    test('nullable fields are null when absent', () {
      final json = _buildStudySessionJson(
        id: 1,
        durationMinutes: 25,
        pomodoroCount: 1,
        eventId: null,
        subjectId: null,
      );

      final result = StudySession.fromJson(json);

      expect(result.id, equals(1));
      expect(result.durationMinutes, equals(25));
      expect(result.pomodoroCount, equals(1));
      expect(result.eventId, isNull);
      expect(result.subjectId, isNull);
    });

    // Property sweep: varying int values for all numeric fields
    test('property sweep — all numeric fields preserved across many int values', () {
      final testCases = [
        (id: 1, dur: 25, pom: 1, eid: 10, sid: 2),
        (id: 7, dur: 50, pom: 2, eid: 20, sid: 5),
        (id: 100, dur: 90, pom: 4, eid: 55, sid: 9),
        (id: 42, dur: 60, pom: 3, eid: 1, sid: 1),
        (id: 999, dur: 120, pom: 6, eid: 300, sid: 15),
      ];

      for (final tc in testCases) {
        final json = _buildStudySessionJson(
          id: tc.id,
          durationMinutes: tc.dur,
          pomodoroCount: tc.pom,
          eventId: tc.eid,
          subjectId: tc.sid,
        );

        final result = StudySession.fromJson(json);

        expect(result.id, equals(tc.id),
            reason: 'id should equal ${tc.id}');
        expect(result.durationMinutes, equals(tc.dur),
            reason: 'durationMinutes should equal ${tc.dur}');
        expect(result.pomodoroCount, equals(tc.pom),
            reason: 'pomodoroCount should equal ${tc.pom}');
        expect(result.eventId, equals(tc.eid),
            reason: 'eventId should equal ${tc.eid}');
        expect(result.subjectId, equals(tc.sid),
            reason: 'subjectId should equal ${tc.sid}');
      }
    });
  });
}
