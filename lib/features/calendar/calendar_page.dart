import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/event_bus/app_event_bus.dart';
import '../../core/event_bus/calendar_events.dart';
import '../../core/mini_app/mini_app_contract.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';
import 'models/calendar_models.dart';
import 'providers/calendar_providers.dart';
import 'services/calendar_api_service.dart';
import 'widgets/month_view.dart';
import 'widgets/today_panel.dart';
import 'widgets/event_form_sheet.dart';
import 'widgets/pomodoro_timer.dart';
import 'widgets/timetable_view.dart';

class CalendarPage extends ConsumerStatefulWidget {
  final String renderMode;    // 'full' | 'modal'
  final String sceneSource;   // 'user_active' | 'agent'
  final int? subjectId;
  final String? taskId;
  final DateTime? prefillDate;
  final String? prefillTitle;
  final String? prefillTime;
  final void Function(MiniAppResult)? onResult;

  const CalendarPage({
    super.key,
    this.renderMode = 'full',
    this.sceneSource = 'user_active',
    this.subjectId,
    this.taskId,
    this.prefillDate,
    this.prefillTitle,
    this.prefillTime,
    this.onResult,
  });

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  final List<void Function()> _busUnsubs = [];

  @override
  void initState() {
    super.initState();
    _prefetchAdjacentMonths();
    _listenEventBus();
  }

  void _prefetchAdjacentMonths() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = ref.read(calendarFocusedDateProvider);
      // 上个月
      ref.read(calendarEventsProvider(DateRange.month(
        DateTime(focused.year, focused.month - 1),
      )));
      // 下个月
      ref.read(calendarEventsProvider(DateRange.month(
        DateTime(focused.year, focused.month + 1, 1),
      )));
    });
  }

  void _listenEventBus() {
    final bus = AppEventBus.instance;
    _busUnsubs.add(bus.on<CalendarEventCreated>().listen((_) {
      ref.invalidate(calendarEventsProvider);
      ref.invalidate(todayEventsProvider);
    }).cancel);
    _busUnsubs.add(bus.on<CalendarEventUpdated>().listen((e) {
      ref.invalidate(calendarEventsProvider(DateRange.month(e.eventDate)));
      ref.invalidate(todayEventsProvider);
    }).cancel);
    _busUnsubs.add(bus.on<CalendarEventCompleted>().listen((_) {
      ref.invalidate(todayEventsProvider);
      ref.invalidate(calendarStatsProvider('7d'));
    }).cancel);
    _busUnsubs.add(bus.on<CalendarEventsBatchCreated>().listen((e) {
      for (final month in e.affectedMonths) {
        ref.invalidate(calendarEventsProvider(DateRange.month(month)));
      }
    }).cancel);
  }

  @override
  void dispose() {
    for (final unsub in _busUnsubs) {
      unsub();
    }
    super.dispose();
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EventFormSheet(
        prefillDate: widget.prefillDate,
        prefillSubjectId: widget.subjectId,
        prefillTitle: widget.prefillTitle,
        prefillTime: widget.prefillTime,
      ),
    );
  }

  void _showEventDetail(BuildContext context, WidgetRef ref, CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EventFormSheet(
        initialEvent: event,
        prefillDate: event.eventDate,
        prefillSubjectId: event.subjectId,
      ),
    );
  }

  void _handleEventDragged(WidgetRef ref, CalendarEvent event, DateTime newDate) async {
    try {
      await ref.read(calendarApiServiceProvider).updateEvent(event.id, {
        'event_date': '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}',
      });
      AppEventBus.instance.fire(CalendarEventUpdated(eventId: event.id, eventDate: newDate));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewMode = ref.watch(calendarViewModeProvider);
    final focused = ref.watch(calendarFocusedDateProvider);
    final pomodoroState = ref.watch(pomodoroTimerProvider);

    final isModal = widget.renderMode == 'modal';

    Widget body = Column(
      children: [
        _CountdownBanner(),
        _ViewSwitcher(current: viewMode),
        Expanded(
          child: viewMode == ViewMode.month
              ? MonthView(
                  focusedDay: focused,
                  onDaySelected: (day) =>
                      ref.read(calendarFocusedDateProvider.notifier).jumpTo(day),
                  onPageChanged: (day) =>
                      ref.read(calendarFocusedDateProvider.notifier).jumpTo(day),
                )
              : TimetableView(
                  visibleDates: viewMode == ViewMode.week
                      ? List.generate(7, (i) => focused.subtract(Duration(days: focused.weekday % 7 - i)))
                      : [focused],
                  onEventTap: (event) => _showEventDetail(context, ref, event),
                  onEventDragged: (event, newDate) => _handleEventDragged(ref, event, newDate),
                ),
        ),
        if (viewMode == ViewMode.month) const TodayPanel(),
        if (pomodoroState.isRunning) const PomodoroFloatingBar(),
      ],
    );

    if (isModal) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('学习日历'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.onResult?.call(const MiniAppResult(success: false, action: 'cancelled'));
              Navigator.pop(context);
            },
          ),
          actions: [_StatsButton(), _TodayButton()],
        ),
        body: body,
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateSheet,
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('学习日历'),
        centerTitle: false,
        actions: [_StatsButton(), _TodayButton()],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── 倒计时横幅 ────────────────────────────────────────────────────────────────

class _CountdownBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(calendarFocusedDateProvider);
    final range = DateRange.month(focused);
    final eventsAsync = ref.watch(calendarEventsProvider(range));

    return eventsAsync.maybeWhen(
      data: (events) {
        final countdowns = events
            .where((e) => e.isCountdown && !e.eventDate.isBefore(DateTime.now()))
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
        if (countdowns.isEmpty) return const SizedBox.shrink();

        final next = countdowns.first;
        final daysLeft = next.eventDate.difference(DateTime.now()).inDays;
        final color = _countdownColor(daysLeft);
        final text = daysLeft == 0
            ? '今天是「${next.title}」，加油！'
            : '距「${next.title}」还有 $daysLeft 天';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: color.withValues(alpha: 0.12),
          child: Row(
            children: [
              Icon(Icons.flag_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Color _countdownColor(int daysLeft) {
    if (daysLeft == 0) return AppColors.error;
    if (daysLeft < 10) return AppColors.error;
    if (daysLeft <= 30) return AppColors.warning;
    return AppColors.success;
  }
}

// ── 视图切换控件 ──────────────────────────────────────────────────────────────

class _ViewSwitcher extends ConsumerWidget {
  final ViewMode current;
  const _ViewSwitcher({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<ViewMode>(
        segments: const [
          ButtonSegment(value: ViewMode.month, label: Text('月')),
          ButtonSegment(value: ViewMode.week, label: Text('周')),
          ButtonSegment(value: ViewMode.day, label: Text('日')),
        ],
        selected: {current},
        onSelectionChanged: (s) =>
            ref.read(calendarViewModeProvider.notifier).switchTo(s.first),
      ),
    );
  }
}

// ── 今天按钮 ──────────────────────────────────────────────────────────────────

class _TodayButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => ref.read(calendarFocusedDateProvider.notifier).jumpToToday(),
      child: const Text('今天'),
    );
  }
}

// ── 统计按钮 ──────────────────────────────────────────────────────────────────

class _StatsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.bar_chart_rounded),
      tooltip: '学习统计',
      onPressed: () => context.push(R.toolkitCalendarStats),
    );
  }
}

// ── 周/日视图占位（timetable 库接入后替换）────────────────────────────────────

