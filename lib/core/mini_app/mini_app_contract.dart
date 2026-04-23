/// MiniApp 标准化入参
class MiniAppInput {
  final String sceneSource; // 'user_active' | 'agent'
  final String renderMode;  // 'full' | 'modal'
  final Map<String, dynamic> params;

  const MiniAppInput({
    required this.sceneSource,
    this.renderMode = 'full',
    this.params = const {},
  });
}

/// MiniApp 标准化出参
class MiniAppResult {
  final bool success;
  final String? action; // 'created' | 'updated' | 'cancelled'
  final Map<String, dynamic> data;

  const MiniAppResult({
    required this.success,
    this.action,
    this.data = const {},
  });
}

/// Calendar Planner 专用入参
class CalendarMiniAppInput extends MiniAppInput {
  final int? subjectId;
  final String? taskId;
  final DateTime? prefillDate;
  final String? prefillTitle;
  final String? prefillTime;   // "HH:mm"
  final int? prefillDuration;  // 分钟

  const CalendarMiniAppInput({
    required super.sceneSource,
    super.renderMode = 'full',
    this.subjectId,
    this.taskId,
    this.prefillDate,
    this.prefillTitle,
    this.prefillTime,
    this.prefillDuration,
  });
}
