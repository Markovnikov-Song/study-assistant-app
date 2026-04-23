// ── Shared helpers ────────────────────────────────────────────────────────────

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

enum ViewMode { month, week, day }

enum PomodoroPhase { idle, focusing, resting, paused }

// ── CalendarEvent ─────────────────────────────────────────────────────────────

class CalendarEvent {
  final int id;
  final int userId;
  final String title;
  final DateTime eventDate;
  final String startTime;       // "HH:MM"
  final int durationMinutes;
  final int? actualDurationMinutes;
  final int? subjectId;
  final String? subjectName;
  final String? subjectColor;
  final String color;
  final String? notes;
  final bool isCompleted;
  final bool isCountdown;
  final String priority;        // high / medium / low
  final String source;          // manual / study-planner / agent / routine
  final int? routineId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.eventDate,
    required this.startTime,
    required this.durationMinutes,
    this.actualDurationMinutes,
    this.subjectId,
    this.subjectName,
    this.subjectColor,
    required this.color,
    this.notes,
    required this.isCompleted,
    required this.isCountdown,
    required this.priority,
    required this.source,
    this.routineId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: _toInt(json['id']),
        userId: _toInt(json['user_id']),
        title: json['title'] as String? ?? '',
        eventDate: DateTime.parse(json['event_date'] as String),
        startTime: json['start_time'] as String? ?? '08:00',
        durationMinutes: _toInt(json['duration_minutes'], fallback: 60),
        actualDurationMinutes: json['actual_duration_minutes'] != null
            ? _toInt(json['actual_duration_minutes'])
            : null,
        subjectId: json['subject_id'] != null ? _toInt(json['subject_id']) : null,
        subjectName: json['subject_name'] as String?,
        subjectColor: json['subject_color'] as String?,
        color: json['color'] as String? ?? '#6366F1',
        notes: json['notes'] as String?,
        isCompleted: json['is_completed'] as bool? ?? false,
        isCountdown: json['is_countdown'] as bool? ?? false,
        priority: json['priority'] as String? ?? 'medium',
        source: json['source'] as String? ?? 'manual',
        routineId: json['routine_id'] != null ? _toInt(json['routine_id']) : null,
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
      );

  static DateTime _parseDateTime(dynamic v) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? DateTime.now();
    }
    return DateTime.now();
  }

  CalendarEvent copyWith({
    bool? isCompleted,
    int? actualDurationMinutes,
    DateTime? eventDate,
    String? startTime,
  }) =>
      CalendarEvent(
        id: id,
        userId: userId,
        title: title,
        eventDate: eventDate ?? this.eventDate,
        startTime: startTime ?? this.startTime,
        durationMinutes: durationMinutes,
        actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
        subjectId: subjectId,
        subjectName: subjectName,
        subjectColor: subjectColor,
        color: color,
        notes: notes,
        isCompleted: isCompleted ?? this.isCompleted,
        isCountdown: isCountdown,
        priority: priority,
        source: source,
        routineId: routineId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

// ── CalendarRoutine ───────────────────────────────────────────────────────────

class CalendarRoutine {
  final int id;
  final String title;
  final String repeatType;
  final int? dayOfWeek;
  final String startTime;
  final int durationMinutes;
  final int? subjectId;
  final String color;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;

  const CalendarRoutine({
    required this.id,
    required this.title,
    required this.repeatType,
    this.dayOfWeek,
    required this.startTime,
    required this.durationMinutes,
    this.subjectId,
    required this.color,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  factory CalendarRoutine.fromJson(Map<String, dynamic> json) => CalendarRoutine(
        id: _toInt(json['id']),
        title: json['title'] as String,
        repeatType: json['repeat_type'] as String,
        dayOfWeek: json['day_of_week'] != null ? _toInt(json['day_of_week']) : null,
        startTime: json['start_time'] as String,
        durationMinutes: _toInt(json['duration_minutes'], fallback: 60),
        subjectId: json['subject_id'] != null ? _toInt(json['subject_id']) : null,
        color: json['color'] as String? ?? '#6366F1',
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ── StudySession ──────────────────────────────────────────────────────────────

class StudySession {
  final int id;
  final int? eventId;
  final int? subjectId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMinutes;
  final int pomodoroCount;
  final DateTime createdAt;

  const StudySession({
    required this.id,
    this.eventId,
    this.subjectId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.pomodoroCount,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: _toInt(json['id']),
        eventId: json['event_id'] != null ? _toInt(json['event_id']) : null,
        subjectId: json['subject_id'] != null ? _toInt(json['subject_id']) : null,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: DateTime.parse(json['ended_at'] as String),
        durationMinutes: _toInt(json['duration_minutes']),
        pomodoroCount: _toInt(json['pomodoro_count']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ── TodayStats ────────────────────────────────────────────────────────────────

class TodayStats {
  final int total;
  final int completed;
  final double completionRate;
  final int totalDurationMinutes;
  final int actualDurationMinutes;

  const TodayStats({
    required this.total,
    required this.completed,
    required this.completionRate,
    required this.totalDurationMinutes,
    required this.actualDurationMinutes,
  });

  factory TodayStats.fromJson(Map<String, dynamic> json) => TodayStats(
        total: _toInt(json['total']),
        completed: _toInt(json['completed']),
        completionRate: _toDouble(json['completion_rate']),
        totalDurationMinutes: _toInt(json['total_duration_minutes']),
        actualDurationMinutes: _toInt(json['actual_duration_minutes']),
      );
}

class TodayEventsResult {
  final List<CalendarEvent> events;
  final TodayStats stats;

  const TodayEventsResult({required this.events, required this.stats});
}

// ── CalendarStats ─────────────────────────────────────────────────────────────

class DailyStatItem {
  final DateTime date;
  final int durationMinutes;
  const DailyStatItem({required this.date, required this.durationMinutes});
}

class SubjectStatItem {
  final int? subjectId;
  final String subjectName;
  final String color;
  final int durationMinutes;
  final double percentage;
  const SubjectStatItem({
    this.subjectId,
    required this.subjectName,
    required this.color,
    required this.durationMinutes,
    required this.percentage,
  });
}

class CalendarStats {
  final String period;
  final int totalDurationMinutes;
  final int checkinDays;
  final int streakDays;
  final List<DailyStatItem> dailyStats;
  final List<SubjectStatItem> subjectStats;

  const CalendarStats({
    required this.period,
    required this.totalDurationMinutes,
    required this.checkinDays,
    required this.streakDays,
    required this.dailyStats,
    required this.subjectStats,
  });

  factory CalendarStats.fromJson(Map<String, dynamic> json) => CalendarStats(
        period: json['period'] as String,
        totalDurationMinutes: _toInt(json['total_duration_minutes']),
        checkinDays: _toInt(json['checkin_days']),
        streakDays: _toInt(json['streak_days']),
        dailyStats: (json['daily_stats'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => DailyStatItem(
                  date: DateTime.parse(e['date'] as String? ?? '1970-01-01'),
                  durationMinutes: _toInt(e['duration_minutes']),
                ))
            .toList(),
        subjectStats: (json['subject_stats'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => SubjectStatItem(
                  subjectId: e['subject_id'] != null ? _toInt(e['subject_id']) : null,
                  subjectName: e['subject_name'] as String? ?? '',
                  color: e['color'] as String? ?? '#6366F1',
                  durationMinutes: _toInt(e['duration_minutes']),
                  percentage: _toDouble(e['percentage']),
                ))
            .toList(),
      );
}

// ── DateRange ─────────────────────────────────────────────────────────────────

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  factory DateRange.month(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    return DateRange(start: start, end: end);
  }

  factory DateRange.week(DateTime day) {
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return DateRange(start: monday, end: sunday);
  }

  String get startIso => '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  String get endIso => '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

// ── PomodoroTimerState ────────────────────────────────────────────────────────

class PomodoroTimerState {
  final PomodoroPhase phase;
  final CalendarEvent? currentEvent;
  final int durationMinutes;
  final int elapsedSeconds;
  final int completedPomodoros;

  const PomodoroTimerState({
    required this.phase,
    this.currentEvent,
    required this.durationMinutes,
    required this.elapsedSeconds,
    required this.completedPomodoros,
  });

  factory PomodoroTimerState.idle() => const PomodoroTimerState(
        phase: PomodoroPhase.idle,
        durationMinutes: 25,
        elapsedSeconds: 0,
        completedPomodoros: 0,
      );

  int get remainingSeconds => durationMinutes * 60 - elapsedSeconds;
  bool get isRunning =>
      phase == PomodoroPhase.focusing || phase == PomodoroPhase.resting;

  PomodoroTimerState copyWith({
    PomodoroPhase? phase,
    CalendarEvent? currentEvent,
    int? durationMinutes,
    int? elapsedSeconds,
    int? completedPomodoros,
  }) =>
      PomodoroTimerState(
        phase: phase ?? this.phase,
        currentEvent: currentEvent ?? this.currentEvent,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      );
}
