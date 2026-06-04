import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/event_bus/app_event_bus.dart';
import '../../core/event_bus/calendar_events.dart';
import '../../core/mini_app/mini_app_contract.dart';
import '../../routes/app_router.dart';
import '../../services/notification_service.dart';
import 'models/calendar_models.dart';
import 'providers/calendar_providers.dart';
import 'services/calendar_api_service.dart';
import 'widgets/month_view.dart';
import 'widgets/today_panel.dart';
import 'widgets/event_form_sheet.dart';
import 'widgets/pomodoro_timer.dart';
import 'widgets/timetable_view.dart';

class CalendarPage extends ConsumerStatefulWidget {
  final String renderMode; // 'full' | 'modal'
  final String sceneSource; // 'user_active' | 'agent'
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
  final List<StreamSubscription> _busUnsubs = [];

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
      ref.read(
        calendarEventsProvider(
          DateRange.month(DateTime(focused.year, focused.month - 1)),
        ),
      );
      // 下个月
      ref.read(
        calendarEventsProvider(
          DateRange.month(DateTime(focused.year, focused.month + 1, 1)),
        ),
      );
    });
  }

  void _listenEventBus() {
    final bus = AppEventBus.instance;
    _busUnsubs.add(
      bus.on<CalendarEventCreated>().listen((_) {
        ref.invalidate(calendarEventsProvider);
        ref.invalidate(todayEventsProvider);
      }),
    );
    _busUnsubs.add(
      bus.on<CalendarEventUpdated>().listen((e) {
        ref.invalidate(calendarEventsProvider(DateRange.month(e.eventDate)));
        ref.invalidate(todayEventsProvider);
      }),
    );
    _busUnsubs.add(
      bus.on<CalendarEventCompleted>().listen((_) {
        ref.invalidate(todayEventsProvider);
        ref.invalidate(calendarStatsProvider('7d'));
      }),
    );
    _busUnsubs.add(
      bus.on<CalendarEventUncompleted>().listen((_) {
        ref.invalidate(todayEventsProvider);
        ref.invalidate(calendarStatsProvider('7d'));
      }),
    );
    _busUnsubs.add(
      bus.on<CalendarEventsBatchCreated>().listen((e) {
        for (final month in e.affectedMonths) {
          ref.invalidate(calendarEventsProvider(DateRange.month(month)));
        }
      }),
    );
    _busUnsubs.add(
      bus.on<CalendarEventDeleted>().listen((e) {
        ref.invalidate(calendarEventsProvider(DateRange.month(e.eventDate)));
        ref.invalidate(todayEventsProvider);
      }),
    );
  }

  @override
  void dispose() {
    for (final unsub in _busUnsubs) {
      unsub.cancel();
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

  void _showEventDetail(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) {
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

  void _handleEventDragged(
    WidgetRef ref,
    CalendarEvent event,
    DateTime newDate,
  ) async {
    try {
      await ref.read(calendarApiServiceProvider).updateEvent(event.id, {
        'event_date':
            '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}',
      });
      AppEventBus.instance.fire(
        CalendarEventUpdated(eventId: event.id, eventDate: newDate),
      );
    } catch (e) {
      debugPrint('[CalendarPage] 事件拖拽保存失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(calendarViewModeProvider);
    final focused = ref.watch(calendarFocusedDateProvider);
    final pomodoroState = ref.watch(pomodoroTimerProvider);
    final isPomodoroActive =
        pomodoroState.isRunning || pomodoroState.phase == PomodoroPhase.paused;

    final isModal = widget.renderMode == 'modal';

    // 用 Stack 让 TodayPanel 固定在底部，彻底避免月份行数变化导致的 overflow
    Widget body = Column(
      children: [
        _CountdownBanner(),
        _ViewSwitcher(current: viewMode),
        Expanded(
          child: viewMode == ViewMode.month
              ? MonthView(
                  focusedDay: focused,
                  onDaySelected: (day) => ref
                      .read(calendarFocusedDateProvider.notifier)
                      .jumpTo(day),
                  onPageChanged: (day) => ref
                      .read(calendarFocusedDateProvider.notifier)
                      .jumpTo(day),
                )
              : TimetableView(
                  visibleDates: viewMode == ViewMode.week
                      ? List.generate(
                          7,
                          (i) => focused.subtract(
                            Duration(days: focused.weekday % 7 - i),
                          ),
                        )
                      : [focused],
                  onEventTap: (event) => _showEventDetail(context, ref, event),
                  onEventDragged: (event, newDate) =>
                      _handleEventDragged(ref, event, newDate),
                ),
        ),
      ],
    );

    // TodayPanel 和 PomodoroBar 固定在 body 底部，不受月历高度影响
    body = Stack(
      children: [
        body,
        if (viewMode == ViewMode.month)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: TodayPanel()),
          ),
        if (isPomodoroActive)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: SafeArea(child: PomodoroFloatingBar()),
          ),
      ],
    );

    if (isModal) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('学习日历'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.onResult?.call(
                const MiniAppResult(success: false, action: 'cancelled'),
              );
              Navigator.pop(context);
            },
          ),
          actions: [_ReminderButton(), _StatsButton(), _TodayButton()],
        ),
        body: body,
        floatingActionButton: isPomodoroActive
            ? null
            : FloatingActionButton(
                onPressed: _openCreateSheet,
                child: const Icon(Icons.add),
              ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('学习日历'),
        centerTitle: false,
        actions: [_ReminderButton(), _StatsButton(), _TodayButton()],
      ),
      body: body,
      floatingActionButton: isPomodoroActive
          ? null
          : FloatingActionButton(
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
    final cs = Theme.of(context).colorScheme;

    return eventsAsync.maybeWhen(
      data: (events) {
        final countdowns =
            events
                .where(
                  (e) => e.isCountdown && !e.eventDate.isBefore(DateTime.now()),
                )
                .toList()
              ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
        if (countdowns.isEmpty) return const SizedBox.shrink();

        final next = countdowns.first;
        final daysLeft = next.eventDate.difference(DateTime.now()).inDays;
        final color = _countdownColor(daysLeft, cs);
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
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Color _countdownColor(int daysLeft, ColorScheme cs) {
    if (daysLeft == 0) return cs.error;
    if (daysLeft < 10) return cs.error;
    if (daysLeft <= 30) return cs.tertiary;
    return cs.secondary;
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
      onPressed: () =>
          ref.read(calendarFocusedDateProvider.notifier).jumpToToday(),
      child: const Text('今天'),
    );
  }
}

// ── 提醒状态与测试 ────────────────────────────────────────────────────────────

class _ReminderButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.notifications_active_outlined),
      tooltip: '提醒测试',
      onPressed: () => _showReminderSheet(context),
    );
  }

  void _showReminderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ReminderSheet(),
    );
  }
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet();

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late Future<NotificationPermissionStatus> _statusFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = NotificationService.instance.getPermissionStatus();
  }

  void _refresh() {
    setState(() {
      _statusFuture = NotificationService.instance.getPermissionStatus();
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _busy = true);
    await NotificationService.instance.requestPermission();
    if (mounted) {
      setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _sendNow() async {
    setState(() => _busy = true);
    await NotificationService.instance.showImmediate(
      id: NotificationIds.calendarTestImmediate,
      title: '📚 学习提醒测试',
      body: '这是一条即时提醒。锁屏和横幅样式由系统通知设置控制。',
      payload: 'route:/toolkit/calendar',
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendIn30Seconds() async {
    setState(() => _busy = true);
    await NotificationService.instance.scheduleCalendarReminder(
      id: NotificationIds.calendarTestScheduled,
      title: '⏰ 该学习了',
      body: '这是一条 30 秒后的日历学习提醒。',
      scheduledTime: DateTime.now().add(const Duration(seconds: 30)),
      payload: 'route:/toolkit/calendar',
    );
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已安排 30 秒后的提醒，请锁屏测试。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: FutureBuilder<NotificationPermissionStatus>(
          future: _statusFuture,
          builder: (context, snapshot) {
            final status = snapshot.data;
            final notificationsOk = status?.notificationsEnabled ?? false;
            final exactOk = status?.exactAlarmsEnabled ?? false;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('学习提醒', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _StatusRow(
                  icon: Icons.notifications_active_outlined,
                  label: '系统通知',
                  ok: notificationsOk,
                  okText: '已开启',
                  badText: '未开启',
                ),
                _StatusRow(
                  icon: Icons.alarm_on_outlined,
                  label: '准时提醒',
                  ok: exactOk,
                  okText: '精确',
                  badText: '近似时间',
                ),
                const SizedBox(height: 8),
                Text(
                  '锁屏横幅、声音和弹出样式还受手机系统的通知频道设置影响。如果测试通知能到达但不弹出，请在系统里把“日历学习提醒”频道设为高优先级。',
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _requestPermission,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('重新请求权限'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _sendNow,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('发送即时测试'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _sendIn30Seconds,
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('30 秒后提醒我'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final String okText;
  final String badText;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.ok,
    required this.okText,
    required this.badText,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(
        ok ? okText : badText,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
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
