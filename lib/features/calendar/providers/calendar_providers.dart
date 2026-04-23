import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_models.dart';
import '../services/calendar_api_service.dart';
import '../../../core/event_bus/app_event_bus.dart';
import '../../../core/event_bus/calendar_events.dart';

// ── 视图模式 ──────────────────────────────────────────────────────────────────

class CalendarViewModeNotifier extends StateNotifier<ViewMode> {
  CalendarViewModeNotifier() : super(ViewMode.month);
  void switchTo(ViewMode mode) => state = mode;
}

final calendarViewModeProvider =
    StateNotifierProvider<CalendarViewModeNotifier, ViewMode>(
  (_) => CalendarViewModeNotifier(),
);

// ── 聚焦日期 ──────────────────────────────────────────────────────────────────

class CalendarFocusedDateNotifier extends StateNotifier<DateTime> {
  CalendarFocusedDateNotifier() : super(DateTime.now());
  void jumpToToday() => state = DateTime.now();
  void jumpTo(DateTime date) => state = date;
}

final calendarFocusedDateProvider =
    StateNotifierProvider<CalendarFocusedDateNotifier, DateTime>(
  (_) => CalendarFocusedDateNotifier(),
);

// ── 事件列表（按日期范围）────────────────────────────────────────────────────

final calendarEventsProvider =
    FutureProvider.family<List<CalendarEvent>, DateRange>((ref, range) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getEvents(startDate: range.startIso, endDate: range.endIso);
});

// ── 今日事件 + 完成率 ─────────────────────────────────────────────────────────

final todayEventsProvider = FutureProvider<TodayEventsResult>((ref) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getTodayEvents();
});

// ── 活跃例程列表 ──────────────────────────────────────────────────────────────

final calendarRoutinesProvider = FutureProvider<List<CalendarRoutine>>((ref) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getRoutines();
});

// ── 统计数据 ──────────────────────────────────────────────────────────────────

final calendarStatsProvider =
    FutureProvider.family<CalendarStats, String>((ref, period) async {
  final api = ref.watch(calendarApiServiceProvider);
  return api.getStats(period: period);
});

// ── 番茄钟（全局单例）────────────────────────────────────────────────────────

class PomodoroTimerNotifier extends StateNotifier<PomodoroTimerState> {
  final Ref _ref;
  Timer? _ticker;
  DateTime? _sessionStart;

  PomodoroTimerNotifier(this._ref) : super(PomodoroTimerState.idle());

  void start(CalendarEvent event, {int durationMinutes = 25}) {
    _ticker?.cancel();
    _sessionStart = DateTime.now();
    state = PomodoroTimerState(
      phase: PomodoroPhase.focusing,
      currentEvent: event,
      durationMinutes: durationMinutes,
      elapsedSeconds: 0,
      completedPomodoros: state.completedPomodoros,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(phase: PomodoroPhase.paused);
  }

  void resume() {
    if (state.phase != PomodoroPhase.paused) return;
    state = state.copyWith(phase: PomodoroPhase.focusing);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> stop({bool markCompleted = false}) async {
    _ticker?.cancel();
    final elapsed = state.elapsedSeconds;
    final event = state.currentEvent;
    if (event != null && elapsed > 0) {
      final durationMin = (elapsed / 60).ceil();
      await _writeSession(event, durationMin, 0);
      if (markCompleted) {
        await _ref.read(calendarApiServiceProvider).updateEvent(
          event.id,
          {'is_completed': true},
        );
        AppEventBus.instance.fire(CalendarEventCompleted(
          eventId: event.id,
          subjectId: event.subjectId,
        ));
      }
    }
    state = PomodoroTimerState.idle();
  }

  void _tick() {
    if (!mounted) return;
    final newElapsed = state.elapsedSeconds + 1;
    final totalSeconds = state.durationMinutes * 60;

    if (newElapsed >= totalSeconds) {
      _onPomodoroComplete();
    } else {
      state = state.copyWith(elapsedSeconds: newElapsed);
    }
  }

  Future<void> _onPomodoroComplete() async {
    _ticker?.cancel();
    final event = state.currentEvent;
    if (event == null) return;

    final session = await _writeSession(event, state.durationMinutes, 1);
    final newCompleted = state.completedPomodoros + 1;

    AppEventBus.instance.fire(PomodoroCompleted(
      eventId: event.id,
      durationMinutes: state.durationMinutes,
      sessionId: session.id,
    ));

    // 更新实际学习时长
    final newActual = (event.actualDurationMinutes ?? 0) + state.durationMinutes;
    await _ref.read(calendarApiServiceProvider).updateEvent(
      event.id,
      {'actual_duration_minutes': newActual},
    );

    // 累计时长达标自动完成
    if (newActual >= event.durationMinutes) {
      await _ref.read(calendarApiServiceProvider).updateEvent(
        event.id,
        {'is_completed': true},
      );
      AppEventBus.instance.fire(CalendarEventCompleted(
        eventId: event.id,
        subjectId: event.subjectId,
      ));
    }

    // 进入休息阶段（5 分钟）
    state = PomodoroTimerState(
      phase: PomodoroPhase.resting,
      currentEvent: event,
      durationMinutes: 5,
      elapsedSeconds: 0,
      completedPomodoros: newCompleted,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<StudySession> _writeSession(
    CalendarEvent event,
    int durationMin,
    int pomodoroCount,
  ) async {
    final now = DateTime.now();
    final started = _sessionStart ?? now.subtract(Duration(minutes: durationMin));
    return _ref.read(calendarApiServiceProvider).createStudySession({
      'event_id': event.id,
      'subject_id': event.subjectId,
      'started_at': started.toIso8601String(),
      'ended_at': now.toIso8601String(),
      'duration_minutes': durationMin,
      'pomodoro_count': pomodoroCount,
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final pomodoroTimerProvider =
    StateNotifierProvider<PomodoroTimerNotifier, PomodoroTimerState>(
  (ref) => PomodoroTimerNotifier(ref),
);
