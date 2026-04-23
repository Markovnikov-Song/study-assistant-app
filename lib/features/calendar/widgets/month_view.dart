import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_providers.dart';

class MonthView extends ConsumerWidget {
  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  const MonthView({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = DateRange.month(focusedDay);
    final eventsAsync = ref.watch(calendarEventsProvider(range));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final events = eventsAsync.valueOrNull ?? [];

    // 按日期分组
    final Map<DateTime, List<CalendarEvent>> eventMap = {};
    for (final e in events) {
      final key = DateTime(e.eventDate.year, e.eventDate.month, e.eventDate.day);
      eventMap.putIfAbsent(key, () => []).add(e);
    }

    return TableCalendar<CalendarEvent>(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: focusedDay,
      locale: 'zh_CN',
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: '月'},
      eventLoader: (day) {
        final key = DateTime(day.year, day.month, day.day);
        return eventMap[key] ?? [];
      },
      selectedDayPredicate: (day) => isSameDay(day, focusedDay),
      onDaySelected: (selected, focused) => onDaySelected(selected),
      onPageChanged: onPageChanged,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(color: Colors.white),
        markerDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        markerSize: 5,
        markersMaxCount: 3,
        markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
        defaultTextStyle: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        weekendTextStyle: TextStyle(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        // 自定义标记点：使用学科颜色
        markerBuilder: (context, day, dayEvents) {
          if (dayEvents.isEmpty) return null;
          final colors = dayEvents
              .take(3)
              .map((e) => _parseColor(e.color))
              .toList();
          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: colors
                  .map((c) => Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
