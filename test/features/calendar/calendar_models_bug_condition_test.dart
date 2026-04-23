// Bug Condition Exploration Test
//
// This test MUST FAIL on unfixed code — failure confirms the bug exists.
// It encodes the expected behavior (no throw, safe defaults returned).
// After the fix is applied (task 3), this test should PASS.
//
// Validates: Requirements 1.4, 1.5

import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/features/calendar/models/calendar_models.dart';

void main() {
  group('Bug Condition Exploration — CalendarStats.fromJson', () {
    // Bug example 1: daily_stats contains a String element instead of a Map.
    // On unfixed code: throws type 'String' is not a subtype of type 'int' of 'index'
    // Expected (fixed) behavior: no exception, dailyStats is empty (string items skipped)
    test(
      'daily_stats with String element does not throw and returns valid model',
      () {
        final json = <String, dynamic>{
          'period': '7d',
          'total_duration_minutes': 120,
          'checkin_days': 3,
          'streak_days': 2,
          'daily_stats': ['2025-01-01'], // String element — triggers the bug
          'subject_stats': [],
        };

        expect(
          () => CalendarStats.fromJson(json),
          returnsNormally,
          reason:
              'CalendarStats.fromJson should not throw when daily_stats contains a String element',
        );

        final result = CalendarStats.fromJson(json);
        expect(result, isA<CalendarStats>());
        // Non-map items should be silently skipped
        expect(result.dailyStats, isEmpty);
      },
    );

    // Bug example 2: subject_stats contains a String element instead of a Map.
    // On unfixed code: throws type 'String' is not a subtype of type 'int' of 'index'
    // Expected (fixed) behavior: no exception, subjectStats is empty (string items skipped)
    test(
      'subject_stats with String element does not throw and returns valid model',
      () {
        final json = <String, dynamic>{
          'period': '7d',
          'total_duration_minutes': 60,
          'checkin_days': 1,
          'streak_days': 1,
          'daily_stats': [],
          'subject_stats': ['math'], // String element — triggers the bug
        };

        expect(
          () => CalendarStats.fromJson(json),
          returnsNormally,
          reason:
              'CalendarStats.fromJson should not throw when subject_stats contains a String element',
        );

        final result = CalendarStats.fromJson(json);
        expect(result, isA<CalendarStats>());
        // Non-map items should be silently skipped
        expect(result.subjectStats, isEmpty);
      },
    );
  });

  group('Bug Condition Exploration — CalendarRoutine.fromJson', () {
    // Bug example 3: numeric fields arrive as String values.
    // On unfixed code: throws type 'String' is not a subtype of type 'num'
    // Expected (fixed) behavior: no exception, fields parsed via int.tryParse
    test(
      'string numeric fields do not throw and return valid model',
      () {
        final json = <String, dynamic>{
          'id': '42',               // String instead of int — triggers the bug
          'duration_minutes': '30', // String instead of int — triggers the bug
          'title': 'Test',
          'repeat_type': 'daily',
          'start_time': '08:00',
          'color': '#6366F1',
          'start_date': '2025-01-01',
          'is_active': true,
          'created_at': '2025-01-01T00:00:00',
        };

        expect(
          () => CalendarRoutine.fromJson(json),
          returnsNormally,
          reason:
              'CalendarRoutine.fromJson should not throw when numeric fields are Strings',
        );

        final result = CalendarRoutine.fromJson(json);
        expect(result, isA<CalendarRoutine>());
        expect(result.id, 42);
        expect(result.durationMinutes, 30);
      },
    );
  });

  group('Bug Condition Exploration — StudySession.fromJson', () {
    // Bug example 4: numeric fields arrive as String values.
    // On unfixed code: throws type 'String' is not a subtype of type 'num'
    // Expected (fixed) behavior: no exception, fields parsed via int.tryParse
    test(
      'string numeric fields do not throw and return valid model',
      () {
        final json = <String, dynamic>{
          'id': '1',               // String instead of int — triggers the bug
          'duration_minutes': '45', // String instead of int — triggers the bug
          'pomodoro_count': '2',   // String instead of int — triggers the bug
          'started_at': '2025-01-01T08:00:00',
          'ended_at': '2025-01-01T08:45:00',
          'created_at': '2025-01-01T00:00:00',
        };

        expect(
          () => StudySession.fromJson(json),
          returnsNormally,
          reason:
              'StudySession.fromJson should not throw when numeric fields are Strings',
        );

        final result = StudySession.fromJson(json);
        expect(result, isA<StudySession>());
        expect(result.id, 1);
        expect(result.durationMinutes, 45);
        expect(result.pomodoroCount, 2);
      },
    );
  });
}
