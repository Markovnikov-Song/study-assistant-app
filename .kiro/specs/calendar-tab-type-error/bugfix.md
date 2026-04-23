# Bugfix Requirements Document

## Introduction

Switching to any of the three calendar views — 今日（日视图）、周、月 — immediately throws a
`type 'String' is not a subtype of type 'int' of 'index'` runtime error, making the entire
Calendar module unusable.

**Root cause (identified through code investigation):**

The error originates from two related problems in the data-parsing layer:

1. **`CalendarStats.fromJson` — unsafe list-item cast** (`lib/features/calendar/models/calendar_models.dart`)
   `daily_stats` and `subject_stats` items are accessed with string keys (`e['date']`, `e['subject_id']`,
   etc.) without first verifying that each element is a `Map`. If FastAPI serialises a Pydantic list
   inside a plain `dict` return and the client receives the items as `String` values (e.g. during a
   partial-decode path), `e['date']` on a `String` calls `String.[]` with a `String` key — Dart's
   `String.[]` operator only accepts `int` (character index), so it throws
   `type 'String' is not a subtype of type 'int' of 'index'`.

2. **`CalendarRoutine.fromJson` — hard numeric cast without guard**
   (`lib/features/calendar/models/calendar_models.dart`)
   Fields such as `id`, `duration_minutes`, etc. are cast directly with `(json['id'] as num).toInt()`.
   If the JSON value arrives as a `String` (which can happen when Dio decodes a response body as a raw
   string and `_asMap` re-parses it), the cast throws a similar type error.

Both paths are reachable on every tab switch because:
- `_CountdownBanner` (always visible) watches `calendarEventsProvider`, which triggers `getEvents`.
- `TodayPanel` (月 view) watches `todayEventsProvider`.
- `TimetableView` (周/日 views) watches `calendarEventsProvider` with a new `DateRange`.
- Any `CalendarEventCompleted` bus event invalidates `calendarStatsProvider`, which re-runs
  `CalendarStats.fromJson` on the next read.

The fix must make all `fromJson` methods in `calendar_models.dart` resilient to receiving numeric
fields as `String` values and list items that are not `Map<String, dynamic>`.

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the user taps the 月（Month）tab in the Calendar page THEN the system throws
`type 'String' is not a subtype of type 'int' of 'index'` and the view fails to render.

1.2 WHEN the user taps the 周（Week）tab in the Calendar page THEN the system throws
`type 'String' is not a subtype of type 'int' of 'index'` and the view fails to render.

1.3 WHEN the user taps the 日（Day / 今日）tab in the Calendar page THEN the system throws
`type 'String' is not a subtype of type 'int' of 'index'` and the view fails to render.

1.4 WHEN `CalendarStats.fromJson` processes a `daily_stats` or `subject_stats` list whose
elements are `String` values rather than `Map<String, dynamic>` THEN the system throws
`type 'String' is not a subtype of type 'int' of 'index'` because `String.[]` requires an
`int` index, not a `String` key.

1.5 WHEN `CalendarRoutine.fromJson` (or any other `fromJson` in `calendar_models.dart`) casts
a JSON field with `(json['field'] as num).toInt()` and the field value is a `String` THEN the
system throws `type 'String' is not a subtype of type 'num'`.

### Expected Behavior (Correct)

2.1 WHEN the user taps the 月（Month）tab THEN the system SHALL render the month calendar view
without throwing any runtime type error.

2.2 WHEN the user taps the 周（Week）tab THEN the system SHALL render the week timetable view
without throwing any runtime type error.

2.3 WHEN the user taps the 日（Day / 今日）tab THEN the system SHALL render the day timetable
view without throwing any runtime type error.

2.4 WHEN `CalendarStats.fromJson` processes a `daily_stats` or `subject_stats` list THEN the
system SHALL skip or safely handle any element that is not a `Map<String, dynamic>`, producing
an empty or partial list rather than throwing.

2.5 WHEN any `fromJson` method in `calendar_models.dart` encounters a numeric JSON field whose
runtime type is `String` THEN the system SHALL parse it with `int.tryParse` / `double.tryParse`
(falling back to a safe default) rather than performing a direct `as num` cast.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the API returns well-formed JSON with all numeric fields as `int` or `double` THEN the
system SHALL CONTINUE TO parse `CalendarEvent`, `CalendarRoutine`, `StudySession`,
`TodayStats`, and `CalendarStats` correctly and display accurate data.

3.2 WHEN the user switches between 月, 周, and 日 tabs multiple times THEN the system SHALL
CONTINUE TO load and display the correct events for each view without data loss or duplication.

3.3 WHEN `CalendarEventCompleted` is fired on the EventBus THEN the system SHALL CONTINUE TO
invalidate `todayEventsProvider` and `calendarStatsProvider('7d')` and refresh the affected
views.

3.4 WHEN the `_CountdownBanner` renders and the API returns a non-empty event list with
`is_countdown: true` THEN the system SHALL CONTINUE TO display the countdown banner with the
correct days-remaining text and colour.

3.5 WHEN `TodayPanel` renders and the API returns today's events THEN the system SHALL CONTINUE
TO display the correct completion progress chip and sorted event list.
