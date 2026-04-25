// lib/features/spec/models/study_plan_models.dart

class TargetSubject {
  final int id;
  final String name;

  const TargetSubject({required this.id, required this.name});

  factory TargetSubject.fromJson(Map<String, dynamic> json) => TargetSubject(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class PlanItem {
  final int id;
  final int planId;
  final int? subjectId;
  final String? subjectName;
  final String nodeId;
  final String nodeText;
  final int estimatedMinutes;
  final String priority; // high / medium / low
  final List<String> dependencyNodeIds;
  final DateTime? plannedDate;
  final String status; // pending / done / skipped
  final DateTime? completedAt;

  const PlanItem({
    required this.id,
    required this.planId,
    this.subjectId,
    this.subjectName,
    required this.nodeId,
    required this.nodeText,
    required this.estimatedMinutes,
    required this.priority,
    required this.dependencyNodeIds,
    this.plannedDate,
    required this.status,
    this.completedAt,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
        id: (json['id'] as num).toInt(),
        planId: (json['plan_id'] as num).toInt(),
        subjectId: json['subject_id'] != null ? (json['subject_id'] as num).toInt() : null,
        subjectName: json['subject_name'] as String?,
        nodeId: json['node_id'] as String? ?? '',
        nodeText: json['node_text'] as String? ?? '',
        estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 20,
        priority: json['priority'] as String? ?? 'medium',
        dependencyNodeIds: (json['dependency_node_ids'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        plannedDate: json['planned_date'] != null
            ? DateTime.tryParse(json['planned_date'] as String)
            : null,
        status: json['status'] as String? ?? 'pending',
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'] as String)
            : null,
      );

  bool get isPending => status == 'pending';
  bool get isDone => status == 'done';
  bool get isSkipped => status == 'skipped';
}

class StudyPlan {
  final int id;
  final String name;
  final List<TargetSubject> targetSubjects;
  final DateTime deadline;
  final int dailyMinutes;
  final String status; // draft / active / completed / abandoned
  final List<PlanItem> items;
  final DateTime createdAt;

  const StudyPlan({
    required this.id,
    required this.name,
    required this.targetSubjects,
    required this.deadline,
    required this.dailyMinutes,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '我的学习计划',
        targetSubjects: (json['target_subjects'] as List?)
                ?.map((e) => TargetSubject.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        deadline: json['deadline'] != null
            ? DateTime.tryParse(json['deadline'] as String) ?? DateTime.now()
            : DateTime.now(),
        dailyMinutes: (json['daily_minutes'] as num?)?.toInt() ?? 60,
        status: json['status'] as String? ?? 'draft',
        items: (json['items'] as List?)
                ?.map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  bool get isActive => status == 'active';
  bool get isDraft => status == 'draft';

  List<PlanItem> get todayItems {
    final today = DateTime.now();
    return items.where((i) {
      if (i.plannedDate == null) return false;
      final d = i.plannedDate!;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
  }
}

class PlanSummary {
  final int planId;
  final int totalItems;
  final int completedItems;
  final int daysRemaining;
  final double todayCompletionRate;
  final List<PlanItem> todayItems;

  const PlanSummary({
    required this.planId,
    required this.totalItems,
    required this.completedItems,
    required this.daysRemaining,
    required this.todayCompletionRate,
    required this.todayItems,
  });

  factory PlanSummary.fromJson(Map<String, dynamic> json) => PlanSummary(
        planId: (json['plan_id'] as num).toInt(),
        totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
        completedItems: (json['completed_items'] as num?)?.toInt() ?? 0,
        daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
        todayCompletionRate: (json['today_completion_rate'] as num?)?.toDouble() ?? 0.0,
        todayItems: (json['today_items'] as List?)
                ?.map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
