// Learning OS — Plan Model
// A Plan is a higher-level construct than a Skill.
// It is owned and executed by ClassAdvisorAgent (班主任).
//
// Hierarchy:
//   Plan (班主任级)
//     └── PlanEntry × N
//           └── Skill (各科老师级)
//                 └── PromptNode × N
//
// Phase 1: Data model skeleton only — no business logic.

import 'package:study_assistant_app/core/skill/skill_model.dart';

/// A single entry in a Plan — one subject, one time slot, one Skill.
class PlanEntry {
  final String id;
  final String subjectId;
  final String skillId;

  /// Scheduled time slot (ISO 8601 string, e.g. "2026-04-18T09:00:00")
  final String scheduledAt;

  /// Duration in minutes.
  final int durationMinutes;

  final PlanEntryStatus status;

  const PlanEntry({
    required this.id,
    required this.subjectId,
    required this.skillId,
    required this.scheduledAt,
    required this.durationMinutes,
    this.status = PlanEntryStatus.pending,
  });
}

enum PlanEntryStatus {
  pending,
  inProgress,
  completed,
  skipped,
}

/// A Plan is a cross-subject learning programme with a time axis.
/// Created by PrincipalAgent + ClassAdvisorAgent in a council meeting.
/// Executed entry-by-entry by SubjectAgents.
class Plan {
  final String id;
  final String name;
  final String description;

  /// The strategic goal this plan serves (e.g. "备战高考").
  final String goalId;

  final List<PlanEntry> entries;
  final DateTime createdAt;
  final DateTime? startsAt;
  final DateTime? endsAt;

  final PlanStatus status;

  /// Which council meeting produced this plan.
  final String? councilDecisionId;

  const Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.goalId,
    required this.entries,
    required this.createdAt,
    this.startsAt,
    this.endsAt,
    this.status = PlanStatus.draft,
    this.councilDecisionId,
  });
}

enum PlanStatus {
  draft,      // 草稿，未激活
  active,     // 执行中
  paused,     // 暂停（用户手动或班主任调整）
  completed,  // 完成
  archived,   // 归档
}

/// Repository interface for Plans.
/// Phase 1: skeleton only.
abstract class PlanLibrary {
  Future<void> save(Plan plan);
  Future<Plan?> get(String id);
  Future<List<Plan>> listActive();
  Future<void> updateStatus(String id, PlanStatus status);
  Future<void> delete(String id);
}
