# Calendar Tab Type Error Bugfix Design

## Overview

Switching to any calendar tab (月/周/日) throws `type 'String' is not a subtype of type 'int' of 'index'` at runtime, making the entire Calendar module unusable. The bug lives entirely in `lib/features/calendar/models/calendar_models.dart` and has two distinct failure points:

1. `CalendarStats.fromJson` iterates `daily_stats` and `subject_stats` lists and accesses items with string keys (e.g. `e['date']`) without first confirming each element is a `Map<String, dynamic>`. When an element is a `String`, Dart's `String.[]` operator expects an `int` index, not a `String` key, and throws immediately.
2. `CalendarRoutine.fromJson` (and `StudySession.fromJson`) cast numeric fields directly with `(json['field'] as num).toInt()`. When the field arrives as a `String`, the `as num` cast fails.

The fix is purely in the parsing layer — no UI, routing, or provider logic changes are needed. All `fromJson` methods will be made resilient by reusing the `_toInt`/`_toDouble` helpers already present in `CalendarEvent` and `TodayStats`, and by guarding list-item access with `whereType<Map<String, dynamic>>()`.

---

## Glossary

- **Bug_Condition (C)**: The condition that triggers the crash — a `fromJson` method receives either a list element that is not a `Map<String, dynamic>`, or a numeric field whose runtime type is `String`.
- **Property (P)**: The desired behavior when the bug condition holds — parsing completes without throwing, returning a valid model with safe defaults for unparseable fields.
- **Preservation**: All existing correct-JSON parsing behavior that must remain unchanged after the fix.
- **`CalendarStats.fromJson`**: The factory constructor in `calendar_models.dart` that parses the `/calendar/stats` API response, including the `daily_stats` and `subject_stats` nested lists.
- **`CalendarRoutine.fromJson`**: The factory constructor that parses routine objects; uses hard `as num` casts for every numeric field.
- **`_toInt` / `_toDouble`**: Static helper methods already defined on `CalendarEvent` and `TodayStats` that safely coerce `int`, `num`, or `String` to the target numeric type with a fallback default.
- **`whereType<T>()`**: Dart iterable method that filters elements to only those of type `T`, silently dropping non-matching items.

---

## Bug Details

### Bug Condition

The bug manifests when `CalendarStats.fromJson` or `CalendarRoutine.fromJson` is called with JSON data where either:
- A list element inside `daily_stats` or `subject_stats` is not a `Map<String, dynamic>` (e.g. it is a `String`), OR
- A numeric field (e.g. `id`, `duration_minutes`) has a runtime type of `String` rather than `int`/`double`.

Both conditions are reachable on every tab switch because `calendarStatsProvider` and `calendarEventsProvider` are re-evaluated whenever the user changes tabs or a `CalendarEventCompleted` bus event fires.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input — a Map<String, dynamic> passed to any fromJson in calendar_models.dart
  OUTPUT: boolean

  IF input is passed to CalendarStats.fromJson THEN
    RETURN (input['daily_stats'] as List).any(e => e is NOT Map<String, dynamic>)
        OR (input['subject_stats'] as List).any(e => e is NOT Map<String, dynamic>)
  END IF

  IF input is passed to CalendarRoutine.fromJson THEN
    RETURN input['id'] is String
        OR input['duration_minutes'] is String
        OR input['day_of_week'] is String
        OR input['subject_id'] is String
  END IF

  RETURN false
END FUNCTION
```

### Examples

- **Bug example 1**: `daily_stats` contains `["2025-01-01", 60]` (strings/ints at top level instead of maps) → `e['date']` on a `String` throws `type 'String' is not a subtype of type 'int' of 'index'`.
- **Bug example 2**: `subject_stats` contains `"math"` (a plain string) → same crash as above.
- **Bug example 3**: `CalendarRoutine.fromJson({'id': '42', 'duration_minutes': '30', ...})` → `('42' as num)` throws `type 'String' is not a subtype of type 'num'`.
- **Non-bug example**: `CalendarRoutine.fromJson({'id': 42, 'duration_minutes': 30, ...})` → parses correctly today and must continue to do so after the fix.

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- When the API returns well-formed JSON with all numeric fields as `int`/`double` and all list items as `Map<String, dynamic>`, every `fromJson` method SHALL continue to produce identical model instances.
- Mouse interaction with calendar events (tap, complete, drag) SHALL remain unaffected.
- Tab switching between 月, 周, and 日 SHALL continue to load and display the correct events and stats.
- `CalendarEventCompleted` bus events SHALL continue to invalidate `todayEventsProvider` and `calendarStatsProvider('7d')` and trigger a refresh.
- The `_CountdownBanner` and `TodayPanel` widgets SHALL continue to render correctly when the API returns valid data.

**Scope:**
All inputs that do NOT satisfy `isBugCondition` — i.e. well-formed JSON with correct types — must be completely unaffected by this fix. This includes:
- All `CalendarEvent.fromJson` calls (already uses `_toInt`; no change needed)
- All `TodayStats.fromJson` calls (already uses `_toInt`/`_toDouble`; no change needed)
- All `StudySession.fromJson` calls (uses hard casts; will be fixed as a precaution but behavior for valid input is unchanged)

---

## Hypothesized Root Cause

1. **Missing map-type guard on list items** (`CalendarStats.fromJson`): The list is cast to `List` and iterated directly. No check confirms each element is a `Map<String, dynamic>` before subscripting with string keys. When FastAPI serialises a Pydantic model in certain edge-case response paths, list items can arrive as serialised strings rather than nested objects.

2. **Hard `as num` casts without String fallback** (`CalendarRoutine.fromJson`, `StudySession.fromJson`): Unlike `CalendarEvent` and `TodayStats` which already use the `_toInt` helper, these two classes use direct `(json['field'] as num).toInt()` casts. If the JSON decoder produces a `String` for a numeric field (e.g. Dio re-parses a raw string body), the cast throws.

3. **Inconsistent helper usage across the file**: `CalendarEvent` and `TodayStats` already have correct, resilient `_toInt`/`_toDouble` helpers. The bug is that `CalendarRoutine`, `StudySession`, and `CalendarStats` were written without adopting the same pattern, creating an inconsistency that only surfaces under certain server response shapes.

---

## Correctness Properties

Property 1: Bug Condition — Safe Parsing of Malformed JSON

_For any_ input where the bug condition holds (`isBugCondition` returns true) — i.e. a `fromJson` call receives a list element that is not a `Map<String, dynamic>`, or a numeric field whose runtime type is `String` — the fixed `fromJson` methods SHALL complete without throwing, returning a model instance with safe default values for unparseable fields (e.g. `0` for ints, `0.0` for doubles, empty list for filtered-out items).

**Validates: Requirements 2.4, 2.5**

Property 2: Preservation — Correct Parsing of Well-Formed JSON

_For any_ input where the bug condition does NOT hold (`isBugCondition` returns false) — i.e. all numeric fields are `int`/`double` and all list items are `Map<String, dynamic>` — the fixed `fromJson` methods SHALL produce exactly the same model instances as the original code, preserving all field values without alteration.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

---

## Fix Implementation

### Changes Required

**File**: `lib/features/calendar/models/calendar_models.dart`

#### 1. Extract shared `_toInt` / `_toDouble` helpers (or promote to top-level)

The helpers currently exist as private static methods on `CalendarEvent` and `TodayStats`. To avoid duplication, promote them to file-level private functions so all classes in the file can use them.

```dart
int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _toDouble(dynamic v, {double fallback = 0.0}) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}
```

Remove the duplicate static methods from `CalendarEvent` and `TodayStats` and update their call sites to use the top-level functions.

#### 2. Fix `CalendarStats.fromJson` — add `whereType` guard on list items

**Specific Change**: Replace the raw `.map((e) => ...)` on `daily_stats` and `subject_stats` with `.whereType<Map<String, dynamic>>().map((e) => ...)` so non-map elements are silently skipped.

```dart
// Before
dailyStats: (json['daily_stats'] as List)
    .map((e) => DailyStatItem(
          date: DateTime.parse(e['date'] as String),
          durationMinutes: (e['duration_minutes'] as num).toInt(),
        ))
    .toList(),

// After
dailyStats: (json['daily_stats'] as List? ?? [])
    .whereType<Map<String, dynamic>>()
    .map((e) => DailyStatItem(
          date: DateTime.parse(e['date'] as String? ?? '1970-01-01'),
          durationMinutes: _toInt(e['duration_minutes']),
        ))
    .toList(),
```

Apply the same pattern to `subjectStats`, and also replace the hard `as num` casts inside the map callbacks with `_toInt`/`_toDouble`.

Also replace the top-level scalar casts in `CalendarStats.fromJson`:
```dart
// Before
totalDurationMinutes: (json['total_duration_minutes'] as num).toInt(),
checkinDays: (json['checkin_days'] as num).toInt(),
streakDays: (json['streak_days'] as num).toInt(),

// After
totalDurationMinutes: _toInt(json['total_duration_minutes']),
checkinDays: _toInt(json['checkin_days']),
streakDays: _toInt(json['streak_days']),
```

#### 3. Fix `CalendarRoutine.fromJson` — replace hard casts with `_toInt`

```dart
// Before
id: (json['id'] as num).toInt(),
durationMinutes: (json['duration_minutes'] as num).toInt(),
dayOfWeek: json['day_of_week'] != null ? (json['day_of_week'] as num).toInt() : null,
subjectId: json['subject_id'] != null ? (json['subject_id'] as num).toInt() : null,

// After
id: _toInt(json['id']),
durationMinutes: _toInt(json['duration_minutes'], fallback: 60),
dayOfWeek: json['day_of_week'] != null ? _toInt(json['day_of_week']) : null,
subjectId: json['subject_id'] != null ? _toInt(json['subject_id']) : null,
```

#### 4. Fix `StudySession.fromJson` — replace hard casts with `_toInt` (precautionary)

Same pattern as `CalendarRoutine` — replace all `(json['field'] as num).toInt()` with `_toInt(json['field'])` for consistency and resilience.

#### 5. No changes outside `calendar_models.dart`

The fix is entirely contained in the model layer. No provider, widget, router, or API client changes are required.

---

## Testing Strategy

### Validation Approach

Two-phase approach: first run exploratory tests against the **unfixed** code to confirm the bug manifests as described and to validate the root cause hypothesis; then run fix-checking and preservation tests against the **fixed** code.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the crash on unfixed code and confirm the root cause.

**Test Plan**: Construct `Map<String, dynamic>` inputs that satisfy `isBugCondition` and pass them directly to the `fromJson` constructors. Assert that the call throws (on unfixed code) and does not throw (on fixed code).

**Test Cases**:
1. **String list item in `daily_stats`**: Pass `{'daily_stats': ['2025-01-01'], 'subject_stats': [], ...}` to `CalendarStats.fromJson` — will throw on unfixed code.
2. **String list item in `subject_stats`**: Pass `{'daily_stats': [], 'subject_stats': ['math'], ...}` to `CalendarStats.fromJson` — will throw on unfixed code.
3. **String `id` in `CalendarRoutine`**: Pass `{'id': '42', 'duration_minutes': '30', 'title': 'Test', ...}` to `CalendarRoutine.fromJson` — will throw on unfixed code.
4. **String numeric fields in `StudySession`**: Pass `{'id': '1', 'duration_minutes': '45', ...}` to `StudySession.fromJson` — will throw on unfixed code.

**Expected Counterexamples**:
- `CalendarStats.fromJson` throws `type 'String' is not a subtype of type 'int' of 'index'` when list items are strings.
- `CalendarRoutine.fromJson` throws `type 'String' is not a subtype of type 'num'` when numeric fields are strings.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed `fromJson` methods complete without throwing and return models with safe defaults.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := fromJson_fixed(input)
  ASSERT no exception thrown
  ASSERT result is valid model instance
  ASSERT numeric fields equal safe defaults where input was unparseable
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed `fromJson` methods produce identical results to the original.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT fromJson_original(input) == fromJson_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is well-suited here because:
- It generates many valid JSON shapes automatically, covering field combinations that manual tests would miss.
- It provides strong guarantees that well-formed inputs are unaffected across the full input domain.
- The input space (valid JSON maps with correct types) is easy to describe as a generator strategy.

**Test Cases**:
1. **Well-formed `CalendarStats`**: Generate random valid stats JSON (all numerics as `int`, all list items as maps) and assert the fixed parser produces the same model as the original.
2. **Well-formed `CalendarRoutine`**: Generate random valid routine JSON and assert field-by-field equality before and after fix.
3. **Well-formed `StudySession`**: Same as above for study sessions.
4. **Tab switching simulation**: Integration test that switches between 月/周/日 tabs with a mocked API returning valid JSON and asserts no errors and correct data display.

### Unit Tests

- `CalendarStats.fromJson` with string list items → no throw, empty/partial list returned.
- `CalendarStats.fromJson` with valid JSON → correct `DailyStatItem` and `SubjectStatItem` lists.
- `CalendarRoutine.fromJson` with string numeric fields → no throw, safe defaults used.
- `CalendarRoutine.fromJson` with valid JSON → all fields parsed correctly.
- `_toInt` helper: `int`, `num`, `String`, `null`, invalid string → correct output for each.
- `_toDouble` helper: same coverage as `_toInt`.

### Property-Based Tests

- For any `Map<String, dynamic>` where all numeric fields are `int`/`double` and all list items are `Map<String, dynamic>`, `CalendarStats.fromJson` produces a model whose `dailyStats.length` equals the input list length.
- For any `CalendarRoutine` JSON with valid types, the fixed parser produces the same `id`, `durationMinutes`, `dayOfWeek`, and `subjectId` as the original parser.
- For any input satisfying `isBugCondition`, no `fromJson` call throws a `TypeError`.

### Integration Tests

- Simulate tab switch to 月 view with mocked stats endpoint returning a response where `daily_stats` contains a non-map element → calendar renders without crashing, stats show partial data.
- Simulate tab switch to 周/日 view with mocked routines endpoint returning string numeric fields → timetable renders without crashing.
- Full tab-switch cycle (月 → 周 → 日 → 月) with valid API responses → all views render correctly and data is consistent.
