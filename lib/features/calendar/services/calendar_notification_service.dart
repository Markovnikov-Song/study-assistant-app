// ─────────────────────────────────────────────────────────────
// calendar_notification_service.dart — 日历事件通知服务
// 为日历事件安排系统通知提醒
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../../../services/notification_service.dart';
import '../models/calendar_models.dart';

/// 日历事件通知服务
/// 负责为日历事件安排系统通知
class CalendarNotificationService {
  CalendarNotificationService._();
  static final CalendarNotificationService instance = CalendarNotificationService._();

  final _notificationService = NotificationService.instance;

  /// 为事件安排通知
  /// 默认在事件开始前 15 分钟提醒
  Future<void> scheduleEventNotification(
    CalendarEvent event, {
    int reminderMinutesBefore = 15,
  }) async {
    try {
      // 解析事件开始时间
      final timeParts = event.startTime.split(':');
      if (timeParts.length != 2) {
        debugPrint('[CalendarNotification] Invalid time format: ${event.startTime}');
        return;
      }

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);
      if (hour == null || minute == null) {
        debugPrint('[CalendarNotification] Invalid time values: ${event.startTime}');
        return;
      }

      // 计算提醒时间
      final eventDateTime = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
        hour,
        minute,
      );

      final reminderTime = eventDateTime.subtract(Duration(minutes: reminderMinutesBefore));

      // 如果提醒时间已经过去，不安排通知
      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint('[CalendarNotification] Reminder time is in the past, skipping');
        return;
      }

      // 生成通知 ID（使用事件 ID + 10000 避免与其他通知冲突）
      final notificationId = 10000 + event.id;

      // 构建通知内容
      final title = '📅 ${event.title}';
      final body = '$reminderMinutesBefore 分钟后开始 · ${event.startTime}';

      // 安排通知
      await _notificationService.scheduleReviewReminder(
        id: notificationId,
        title: title,
        body: body,
        scheduledTime: reminderTime,
        payload: 'route:/toolkit/calendar',
      );

      debugPrint('[CalendarNotification] Scheduled notification for event ${event.id} at $reminderTime');
    } catch (e, st) {
      debugPrint('[CalendarNotification] Failed to schedule notification: $e');
      debugPrint(st.toString());
    }
  }

  /// 取消事件通知
  Future<void> cancelEventNotification(int eventId) async {
    final notificationId = 10000 + eventId;
    await _notificationService.cancel(notificationId);
    debugPrint('[CalendarNotification] Cancelled notification for event $eventId');
  }

  /// 批量安排事件通知
  Future<void> scheduleMultipleEvents(
    List<CalendarEvent> events, {
    int reminderMinutesBefore = 15,
  }) async {
    for (final event in events) {
      await scheduleEventNotification(event, reminderMinutesBefore: reminderMinutesBefore);
    }
  }

  /// 取消多个事件的通知
  Future<void> cancelMultipleEvents(List<int> eventIds) async {
    for (final eventId in eventIds) {
      await cancelEventNotification(eventId);
    }
  }

  /// 重新安排所有未来事件的通知
  /// 用于用户修改提醒设置后重新调度
  Future<void> rescheduleAllEvents(
    List<CalendarEvent> events, {
    int reminderMinutesBefore = 15,
  }) async {
    // 先取消所有日历事件通知（ID 范围 10000-19999）
    for (int i = 0; i < 10000; i++) {
      await _notificationService.cancel(10000 + i);
    }

    // 重新安排
    await scheduleMultipleEvents(events, reminderMinutesBefore: reminderMinutesBefore);
  }
}
