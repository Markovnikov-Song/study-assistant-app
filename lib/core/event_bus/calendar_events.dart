import 'app_event_bus.dart';

/// 单个事件创建完成
class CalendarEventCreated extends AppEvent {
  final int eventId;
  final DateTime eventDate;
  final String? source;
  const CalendarEventCreated({
    required this.eventId,
    required this.eventDate,
    this.source,
  });
}

/// 事件更新（含拖拽移动、字段修改）
class CalendarEventUpdated extends AppEvent {
  final int eventId;
  final DateTime eventDate;
  const CalendarEventUpdated({
    required this.eventId,
    required this.eventDate,
  });
}

/// 事件标记为已完成
class CalendarEventCompleted extends AppEvent {
  final int eventId;
  final int? subjectId;
  final String? taskId;          // 关联的 study-planner task id
  final String? mindmapNodeId;   // 关联的思维导图节点 id
  const CalendarEventCompleted({
    required this.eventId,
    this.subjectId,
    this.taskId,
    this.mindmapNodeId,
  });
}

/// 事件取消完成（反向打卡）
class CalendarEventUncompleted extends AppEvent {
  final int eventId;
  const CalendarEventUncompleted({required this.eventId});
}

/// 事件被删除
class CalendarEventDeleted extends AppEvent {
  final int eventId;
  final DateTime eventDate;
  final String? source;
  const CalendarEventDeleted({
    required this.eventId,
    required this.eventDate,
    this.source,
  });
}

/// 批量事件创建完成（study-planner 等外部写入）
class CalendarEventsBatchCreated extends AppEvent {
  final int createdCount;
  final List<DateTime> affectedMonths;
  final String source;
  const CalendarEventsBatchCreated({
    required this.createdCount,
    required this.affectedMonths,
    required this.source,
  });
}

/// 番茄钟完成一个周期
class PomodoroCompleted extends AppEvent {
  final int eventId;
  final int durationMinutes;
  final int sessionId;
  const PomodoroCompleted({
    required this.eventId,
    required this.durationMinutes,
    required this.sessionId,
  });
}
