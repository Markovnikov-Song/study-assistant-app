// lib/services/calendar_service.dart

import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/daily_task.dart';
import 'notification_service.dart';

/// 日历服务 - 管理设备日历事件和学习计划集成
class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  bool _initialized = false;
  String? _defaultCalendarId;

  // ── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 请求权限
    var permissionsGranted = await _calendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && (permissionsGranted.data ?? false) == false) {
      permissionsGranted = await _calendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || (permissionsGranted.data ?? false) == false) {
        debugPrint('[CalendarService] 日历权限被拒绝');
        return;
      }
    }

    // 获取默认日历
    final calendarsResult = await _calendarPlugin.retrieveCalendars();
    if (calendarsResult.isSuccess && calendarsResult.data != null) {
      final calendars = calendarsResult.data!;
      // 优先使用默认日历，否则使用第一个
      _defaultCalendarId = calendars.firstWhere(
        (c) => c.isDefault == true,
        orElse: () => calendars.first,
      ).id;
    }
  }

  /// 获取可用日历列表
  Future<List<Calendar>> getCalendars() async {
    final result = await _calendarPlugin.retrieveCalendars();
    if (result.isSuccess && result.data != null) {
      return result.data!;
    }
    return [];
  }

  /// 设置默认日历
  Future<void> setDefaultCalendar(String calendarId) async {
    _defaultCalendarId = calendarId;
  }

  // ── 事件操作 ──────────────────────────────────────────────────────────────

  /// 添加日历事件
  Future<bool> addEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required Duration duration,
    String? linkedNodeId,
    Map<String, dynamic>? extraData,
  }) async {
    if (_defaultCalendarId == null) {
      debugPrint('[CalendarService] 未设置默认日历');
      return false;
    }

    // 构建带有额外数据的描述
    String eventDescription = description;
    if (extraData != null && extraData.isNotEmpty) {
      eventDescription = '$description\n${extraData.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
    }

    final event = Event(
      _defaultCalendarId,
      title: title,
      description: eventDescription,
      start: tz.TZDateTime.from(startTime, tz.local),
      end: tz.TZDateTime.from(startTime.add(duration), tz.local),
    );

    final result = await _calendarPlugin.createOrUpdateEvent(event);
    return result?.isSuccess ?? false;
  }

  /// 获取指定日期范围的事件
  Future<List<Event>> getEvents(DateTime start, DateTime end) async {
    if (_defaultCalendarId == null) return [];

    final result = await _calendarPlugin.retrieveEvents(
      _defaultCalendarId,
      RetrieveEventsParams(startDate: start, endDate: end),
    );

    if (result.isSuccess && result.data != null) {
      return result.data!;
    }
    return [];
  }

  /// 删除事件
  Future<bool> deleteEvent(String eventId) async {
    if (_defaultCalendarId == null) return false;

    final result = await _calendarPlugin.deleteEvent(_defaultCalendarId, eventId);
    return result.isSuccess;
  }

  // ── 学习计划集成 ──────────────────────────────────────────────────────────

  /// 将学习计划任务写入日历
  Future<void> importPlanToCalendar({
    required int planId,
    required List<DailyTask> tasks,
  }) async {
    // 遍历计划的每日任务，创建日历事件
    for (final task in tasks) {
      final taskDate = DateTime.tryParse(task.date);
      if (taskDate == null) continue;

      await addEvent(
        title: '📚 ${task.title}',
        description: '学习任务 - ${task.skillId}',
        startTime: taskDate,
        duration: Duration(minutes: task.durationMinutes),
        linkedNodeId: task.nodeId,
        extraData: {
          'planId': planId,
          'taskId': task.nodeId,
          'skillId': task.skillId,
        },
      );
    }
  }

  /// 学习计划提醒设置
  Future<void> scheduleStudyReminders({
    required int planId,
    required DateTime startDate,
    required DateTime endDate,
    int reminderHour = 20,
    int reminderMinute = 0,
  }) async {
    final notificationService = NotificationService.instance;

    // 计划开始前一天提醒
    await notificationService.scheduleNotification(
      id: NotificationIds.planGenerated + planId,
      title: '📋 备考计划即将开始',
      body: '您的学习计划将于明天开始，准备好了吗？',
      scheduledTime: startDate.subtract(const Duration(days: 1)),
    );

    // 每日学习提醒
    DateTime current = startDate;
    int notificationId = NotificationIds.dailyStudyReminder + planId * 100;

    while (!current.isAfter(endDate)) {
      await notificationService.scheduleDailyAt(
        id: notificationId,
        title: '📚 今日学习任务',
        body: '点击查看今天的学习安排',
        hour: reminderHour,
        minute: reminderMinute,
        payload: 'plan:$planId',
      );
      current = current.add(const Duration(days: 1));
      notificationId++;
    }
  }

  /// 任务开始前提醒
  Future<void> scheduleTaskReminders(List<DailyTask> tasks) async {
    final notificationService = NotificationService.instance;

    for (final task in tasks) {
      final taskTime = DateTime.tryParse(task.date);
      if (taskTime == null) continue;

      // 任务前15分钟提醒
      await notificationService.scheduleNotification(
        id: task.nodeId.hashCode,
        title: '⏰ 即将开始: ${task.title}',
        body: '点击开始学习',
        scheduledTime: taskTime.subtract(const Duration(minutes: 15)),
        payload: 'task:${task.nodeId}',
      );
    }
  }
}