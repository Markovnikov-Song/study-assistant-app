import 'package:flutter/material.dart';

// ─── 枚举 ─────────────────────────────────────────────────────

enum PomodoroPhase { idle, focusing, resting, paused }

enum ViewMode { month, week, day }

// ─── DateRange ────────────────────────────────────────────────

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  /// 构造某月的日期范围（月初到月末）
  factory DateRange.month(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    return DateRange(start: start, end: end);
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

// ─── CalendarEvent ────────────────────────────────────────────

class CalendarEvent {
  final int id;
  final int userId;
  final String title;
  final DateTime eventDate;
  final String startTime; // "HH:mm"
  final int durationMinutes;
  final int? actualDurationMinutes;
  final int? subjectId;
  final String? subjectName;
  final String? subjectColor;
  final String color;
  final String? notes;
  final bool isCompleted;
  final bool isCountdown;
  final String priority; // 'high' | 'medium' | 'low'
  final String source;   // 'manual' | 'study-planner' | 'agent'
  final int? routineId;
  final DateTime createdAt;

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
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: (json['id'] as num).toInt(),
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String,
        eventDate: DateTime.parse(json['event_date'] as String),
        startTime: json['start_time'] as String,
        durationMinutes: (json['duration_minutes'] as num).toInt(),
        actualDurationMinutes: (json['actual_duration_minutes'] as num?)?.toInt(),
        subjectId: (json['subject_id'] as num?)?.toInt(),
        subjectName: json['subject_name'] as String?,
        subjectColor: json['subject_color'] as String?,
        color: json['color'] as String? ?? '#6366F1',
        notes: json['notes'] as String?,
        isCompleted: json['is_completed'] as bool? ?? false,
        isCountdown: json['is_countdown'] as bool? ?? false,
        priority: json['priority'] as String? ?? 'medium',
        source: json['source'] as String? ?? 'manual',
        routineId: (json['routine_id'] as num?)?.toInt(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String).toLocal()
            : DateTime.now(),
      );

  CalendarEvent copyWith({
    int? id,
    int? userId,
    String? title,
    DateTime? eventDate,
    String? startTime,
    int? durationMinutes,
    int? actualDurationMinutes,
    int? subjectId,
    String? subjectName,
    String? subjectColor,
    String? color,
    String? notes,
    bool? isCompleted,
    bool? isCountdown,
    String? priority,
    String? source,
    int? routineId,
    DateTime? createdAt,
  }) =>
      CalendarEvent(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        eventDate: eventDate ?? this.eventDate,
        startTime: startTime ?? this.startTime,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
        subjectId: subjectId ?? this.subjectId,
        subjectName: subjectName ?? this.subjectName,
        subjectColor: subjectColor ?? this.subjectColor,
        color: color ?? this.color,
        notes: notes ?? this.notes,
        isCompleted: isCompleted ?? this.isCompleted,
        isCountdown: isCountdown ?? this.isCountdown,
        priority: priority ?? this.priority,
        source: source ?? this.source,
        routineId: routineId ?? this.routineId,
        createdAt: createdAt ?? this.createdAt,
      );

  /// 将 startTime 字符串解析为 TimeOfDay
  TimeOfDay get startTimeOfDay {
    final parts = startTime.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// 将 color 字符串解析为 Color
  Color get colorValue {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

// ─── CalendarRoutine ──────────────────────────────────────────

class CalendarRoutine {
  final int id;
  final int userId;
  final String title;
  final String repeatType; // 'daily' | 'weekly' | 'monthly'
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
    required this.userId,
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
        id: (json['id'] as num).toInt(),
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String,
        repeatType: json['repeat_type'] as String,
        dayOfWeek: (json['day_of_week'] as num?)?.toInt(),
        startTime: json['start_time'] as String,
        durationMinutes: (json['duration_minutes'] as num).toInt(),
        subjectId: (json['subject_id'] as num?)?.toInt(),
        color: json['color'] as String? ?? '#6366F1',
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String)
            : null,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String).toLocal()
            : DateTime.now(),
      );
}

// ─── StudySession ─────────────────────────────────────────────

class StudySession {
  final int id;
  final int userId;
  final int? eventId;
  final int? subjectId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMinutes;
  final int pomodoroCount;
  final DateTime createdAt;

  const StudySession({
    required this.id,
    required this.userId,
    this.eventId,
    this.subjectId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.pomodoroCount,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: (json['id'] as num).toInt(),
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        eventId: (json['event_id'] as num?)?.toInt(),
        subjectId: (json['subject_id'] as num?)?.toInt(),
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
        endedAt: DateTime.parse(json['ended_at'] as String).toLocal(),
        durationMinutes: (json['duration_minutes'] as num).toInt(),
        pomodoroCount: (json['pomodoro_count'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String).toLocal()
            : DateTime.now(),
      );
}

// ─── DailyStats ───────────────────────────────────────────────

class DailyStats {
  final DateTime date;
  final int durationMinutes;

  const DailyStats({required this.date, required this.durationMinutes});

  factory DailyStats.fromJson(Map<String, dynamic> json) => DailyStats(
        date: DateTime.parse(json['date'] as String),
        durationMinutes: (json['duration_minutes'] as num).toInt(),
      );
}

// ─── SubjectStats ─────────────────────────────────────────────

class SubjectStats {
  final int subjectId;
  final String subjectName;
  final String color;
  final int durationMinutes;
  final double percentage;

  const SubjectStats({
    required this.subjectId,
    required this.subjectName,
    required this.color,
    required this.durationMinutes,
    required this.percentage,
  });

  factory SubjectStats.fromJson(Map<String, dynamic> json) => SubjectStats(
        subjectId: (json['subject_id'] as num).toInt(),
        subjectName: json['subject_name'] as String,
        color: json['color'] as String? ?? '#6366F1',
        durationMinutes: (json['duration_minutes'] as num).toInt(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

// ─── CalendarStats ────────────────────────────────────────────

class CalendarStats {
  final String period;
  final int totalDurationMinutes;
  final int checkinDays;
  final int streakDays;
  final List<DailyStats> dailyStats;
  final List<SubjectStats> subjectStats;

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
        totalDurationMinutes: (json['total_duration_minutes'] as num).toInt(),
        checkinDays: (json['checkin_days'] as num).toInt(),
        streakDays: (json['streak_days'] as num).toInt(),
        dailyStats: (json['daily_stats'] as List)
            .map((e) => DailyStats.fromJson(e))
            .toList(),
        subjectStats: (json['subject_stats'] as List)
            .map((e) => SubjectStats.fromJson(e))
            .toList(),
      );
}

// ─── TodayEventsResult ────────────────────────────────────────

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
        total: (json['total'] as num).toInt(),
        completed: (json['completed'] as num).toInt(),
        completionRate: (json['completion_rate'] as num).toDouble(),
        totalDurationMinutes: (json['total_duration_minutes'] as num).toInt(),
        actualDurationMinutes: (json['actual_duration_minutes'] as num).toInt(),
      );
}

class TodayEventsResult {
  final List<CalendarEvent> events;
  final TodayStats stats;

  const TodayEventsResult({required this.events, required this.stats});

  factory TodayEventsResult.fromJson(Map<String, dynamic> json) => TodayEventsResult(
        events: (json['events'] as List)
            .map((e) => CalendarEvent.fromJson(e))
            .toList(),
        stats: TodayStats.fromJson(json['stats']),
      );
}

// ─── PomodoroTimerState ───────────────────────────────────────

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
        currentEvent: null,
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
