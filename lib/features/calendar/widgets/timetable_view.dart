import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_providers.dart';

/// 周/日时间轴视图（自定义实现，不依赖 timetable 库）
class TimetableView extends ConsumerWidget {
  final List<DateTime> visibleDates;
  final ValueChanged<CalendarEvent> onEventTap;
  final void Function(CalendarEvent, DateTime) onEventDragged;

  const TimetableView({
    super.key,
    required this.visibleDates,
    required this.onEventTap,
    required this.onEventDragged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (visibleDates.isEmpty) return const SizedBox.shrink();

    final start = visibleDates.first;
    final end = visibleDates.last;
    final range = DateRange(start: start, end: end);
    final eventsAsync = ref.watch(calendarEventsProvider(range));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (events) => _TimetableBody(
        visibleDates: visibleDates,
        events: events,
        onEventTap: onEventTap,
        onEventDragged: onEventDragged,
        isDark: isDark,
      ),
    );
  }
}

class _TimetableBody extends StatelessWidget {
  final List<DateTime> visibleDates;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final void Function(CalendarEvent, DateTime) onEventDragged;
  final bool isDark;

  static const double _hourHeight = 60.0;
  static const double _timeColWidth = 48.0;
  static const int _startHour = 6;
  static const int _endHour = 23;

  const _TimetableBody({
    required this.visibleDates,
    required this.events,
    required this.onEventTap,
    required this.onEventDragged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final totalHours = _endHour - _startHour;

    return Column(
      children: [
        // 日期标题行
        _DateHeader(dates: visibleDates, isDark: isDark),
        // 时间轴主体
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: totalHours * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间列
                  SizedBox(
                    width: _timeColWidth,
                    child: Column(
                      children: List.generate(totalHours, (i) {
                        final hour = _startHour + i;
                        return SizedBox(
                          height: _hourHeight,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8, top: 2),
                              child: Text(
                                '$hour:00',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // 日期列
                  ...visibleDates.map((date) {
                    final dayEvents = events.where((e) {
                      return e.eventDate.year == date.year &&
                          e.eventDate.month == date.month &&
                          e.eventDate.day == date.day;
                    }).toList();

                    return Expanded(
                      child: _DayColumn(
                        date: date,
                        events: dayEvents,
                        onEventTap: onEventTap,
                        onEventDragged: onEventDragged,
                        isDark: isDark,
                        hourHeight: _hourHeight,
                        startHour: _startHour,
                        endHour: _endHour,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final List<DateTime> dates;
  final bool isDark;

  const _DateHeader({required this.dates, required this.isDark});

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48), // 时间列占位
          ...dates.map((d) {
            final isToday = d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdays[d.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: isToday
                        ? const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Center(
                      child: Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? Colors.white
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final void Function(CalendarEvent, DateTime) onEventDragged;
  final bool isDark;
  final double hourHeight;
  final int startHour;
  final int endHour;

  const _DayColumn({
    required this.date,
    required this.events,
    required this.onEventTap,
    required this.onEventDragged,
    required this.isDark,
    required this.hourHeight,
    required this.startHour,
    required this.endHour,
  });

  @override
  Widget build(BuildContext context) {
    final totalHours = endHour - startHour;

    return Stack(
      children: [
        // 时间格线
        Column(
          children: List.generate(totalHours, (i) {
            return Container(
              height: hourHeight,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: (isDark ? AppColors.borderDark : AppColors.border)
                        .withOpacity(0.5),
                    width: 0.5,
                  ),
                  left: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                    width: 0.5,
                  ),
                ),
              ),
            );
          }),
        ),
        // 事件色块
        ...events.map((e) => _EventBlock(
              event: e,
              onTap: () => onEventTap(e),
              hourHeight: hourHeight,
              startHour: startHour,
            )),
      ],
    );
  }
}

class _EventBlock extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final double hourHeight;
  final int startHour;

  const _EventBlock({
    required this.event,
    required this.onTap,
    required this.hourHeight,
    required this.startHour,
  });

  @override
  Widget build(BuildContext context) {
    final parts = event.startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final topOffset = (hour - startHour + minute / 60) * hourHeight;
    final height = (event.durationMinutes / 60) * hourHeight;

    return Positioned(
      top: topOffset,
      left: 2,
      right: 2,
      height: height.clamp(20.0, double.infinity),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _parseColor(event.color).withOpacity(event.isCompleted ? 0.4 : 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
