# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Type Error on Malformed JSON
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the crash on unfixed code
  - **Scoped PBT Approach**: Scope the property to the concrete failing cases to ensure reproducibility
  - Test `CalendarStats.fromJson` with `daily_stats` containing a `String` element (e.g. `['2025-01-01']`) — asserts no exception is thrown and a valid model is returned
  - Test `CalendarStats.fromJson` with `subject_stats` containing a `String` element (e.g. `['math']`) — same assertion
  - Test `CalendarRoutine.fromJson` with string numeric fields (e.g. `{'id': '42', 'duration_minutes': '30', ...}`) — asserts no exception is thrown
  - Test `StudySession.fromJson` with string numeric fields (e.g. `{'id': '1', 'duration_minutes': '45', ...}`) — asserts no exception is thrown
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS with `type 'String' is not a subtype of type 'int' of 'index'` or `type 'String' is not a subtype of type 'num'` (this is correct — it proves the bug exists)
  - Document counterexamples found (e.g. `CalendarStats.fromJson({'daily_stats': ['2025-01-01'], ...})` throws on unfixed code)
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.4, 1.5_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Well-Formed JSON Parses Identically
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: `CalendarStats.fromJson` with all-int numerics and all-map list items produces correct `DailyStatItem` and `SubjectStatItem` lists on unfixed code
  - Observe: `CalendarRoutine.fromJson` with `{'id': 42, 'duration_minutes': 30, ...}` produces correct field values on unfixed code
  - Observe: `StudySession.fromJson` with valid int fields produces correct model on unfixed code
  - Write property-based test: for any well-formed `CalendarStats` JSON (all numerics as `int`/`double`, all list items as `Map<String, dynamic>`), the parser produces a model whose `dailyStats.length` equals the input list length and all field values match the input
  - Write property-based test: for any well-formed `CalendarRoutine` JSON, `id`, `durationMinutes`, `dayOfWeek`, and `subjectId` equal the input values
  - Write property-based test: for any well-formed `StudySession` JSON, all numeric fields equal the input values
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 3. Fix type errors in `lib/features/calendar/models/calendar_models.dart`

  - [x] 3.1 Promote `_toInt` / `_toDouble` to file-level private functions
    - Add top-level `_toInt(dynamic v, {int fallback = 0})` and `_toDouble(dynamic v, {double fallback = 0.0})` functions at the top of the file (before any class definitions)
    - Remove the duplicate `static _toInt` from `CalendarEvent` and update its call sites to use the top-level function
    - Remove the duplicate `static _toInt` and `static _toDouble` from `TodayStats` and update their call sites to use the top-level functions
    - _Bug_Condition: isBugCondition(input) — numeric field is a String, or list item is not a Map<String, dynamic>_
    - _Expected_Behavior: fromJson completes without throwing; numeric fields fall back to safe defaults; non-map list items are silently skipped_
    - _Preservation: CalendarEvent and TodayStats parsing behavior is identical for well-formed inputs_
    - _Requirements: 2.4, 2.5, 3.1_

  - [x] 3.2 Fix `CalendarStats.fromJson` — add `whereType` guard and replace hard casts
    - Replace `(json['daily_stats'] as List)` with `(json['daily_stats'] as List? ?? []).whereType<Map<String, dynamic>>()`
    - Replace `(json['subject_stats'] as List)` with `(json['subject_stats'] as List? ?? []).whereType<Map<String, dynamic>>()`
    - Replace `(e['duration_minutes'] as num).toInt()` inside `dailyStats` map with `_toInt(e['duration_minutes'])`
    - Replace `(e['subject_id'] as num).toInt()` inside `subjectStats` map with `_toInt(e['subject_id'])`
    - Replace `(e['duration_minutes'] as num).toInt()` inside `subjectStats` map with `_toInt(e['duration_minutes'])`
    - Replace `(e['percentage'] as num).toDouble()` inside `subjectStats` map with `_toDouble(e['percentage'])`
    - Replace top-level scalar casts `(json['total_duration_minutes'] as num).toInt()`, `(json['checkin_days'] as num).toInt()`, `(json['streak_days'] as num).toInt()` with `_toInt(...)` equivalents
    - _Bug_Condition: (input['daily_stats'] as List).any(e => e is NOT Map<String, dynamic>) OR (input['subject_stats'] as List).any(e => e is NOT Map<String, dynamic>)_
    - _Requirements: 2.4, 2.5_

  - [x] 3.3 Fix `CalendarRoutine.fromJson` — replace hard `as num` casts with `_toInt`
    - Replace `(json['id'] as num).toInt()` with `_toInt(json['id'])`
    - Replace `(json['duration_minutes'] as num).toInt()` with `_toInt(json['duration_minutes'], fallback: 60)`
    - Replace `(json['day_of_week'] as num).toInt()` with `_toInt(json['day_of_week'])`
    - Replace `(json['subject_id'] as num).toInt()` with `_toInt(json['subject_id'])`
    - _Bug_Condition: input['id'] is String OR input['duration_minutes'] is String OR input['day_of_week'] is String OR input['subject_id'] is String_
    - _Requirements: 2.5, 3.1_

  - [x] 3.4 Fix `StudySession.fromJson` — replace hard `as num` casts with `_toInt` (precautionary)
    - Replace all `(json['field'] as num).toInt()` patterns with `_toInt(json['field'])` for `id`, `event_id`, `subject_id`, `duration_minutes`, `pomodoro_count`
    - _Bug_Condition: any numeric field in StudySession JSON has runtime type String_
    - _Requirements: 2.5, 3.1_

  - [x] 3.5 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Type Error on Malformed JSON
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - The test from task 1 encodes the expected behavior (no throw, safe defaults returned)
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.4, 2.5_

  - [x] 3.6 Verify preservation tests still pass
    - **Property 2: Preservation** - Well-Formed JSON Parses Identically
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint — Ensure all tests pass
  - Run the full test suite for `calendar_models.dart`
  - Confirm Property 1 (bug condition) passes — malformed JSON no longer throws
  - Confirm Property 2 (preservation) passes — well-formed JSON still parses identically
  - Ensure all tests pass; ask the user if questions arise
