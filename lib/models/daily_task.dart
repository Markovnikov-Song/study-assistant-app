// lib/models/daily_task.dart

/// 学习计划每日任务模型
class DailyTask {
  final String nodeId;
  final String title;
  final String skillId;
  final int durationMinutes;
  final String phase; // "基础"/"强化"/"冲刺"
  final String date;
  final TaskStatus status;

  const DailyTask({
    required this.nodeId,
    required this.title,
    required this.skillId,
    required this.durationMinutes,
    required this.phase,
    required this.date,
    this.status = TaskStatus.pending,
  });

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      nodeId: json['node_id'] ?? '',
      title: json['title'] ?? '',
      skillId: json['skill_id'] ?? 'mindmap_learning',
      durationMinutes: json['duration'] ?? 30,
      phase: json['phase'] ?? '基础',
      date: json['date'] ?? '',
      status: TaskStatus.values.firstWhere(
        (s) => s.name == (json['status'] ?? 'pending'),
        orElse: () => TaskStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'title': title,
        'skill_id': skillId,
        'duration': durationMinutes,
        'phase': phase,
        'date': date,
        'status': status.name,
      };

  DailyTask copyWith({
    String? nodeId,
    String? title,
    String? skillId,
    int? durationMinutes,
    String? phase,
    String? date,
    TaskStatus? status,
  }) {
    return DailyTask(
      nodeId: nodeId ?? this.nodeId,
      title: title ?? this.title,
      skillId: skillId ?? this.skillId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      phase: phase ?? this.phase,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }
}

/// 任务状态枚举
enum TaskStatus { pending, completed, skipped }