// Learning OS — Multi-Agent Council
// Defines the role contracts for each Agent in the council.
// Phase 1: Interface skeleton only — no business logic.
//
// Role hierarchy (inspired by thyroid axis negative feedback):
//
//   PrincipalAgent (校长)        ← strategic layer, slow feedback
//       ↓
//   ClassAdvisorAgent (班主任)   ← planning layer, medium feedback
//       ↓
//   SubjectAgent × N (各科老师)  ← execution layer, no proactive feedback
//
//   CompanionAgent (同桌)        ← monitoring layer, all feedback levels
//       → fast  → SubjectAgent
//       → medium → ClassAdvisorAgent
//       → slow  → PrincipalAgent

import 'package:study_assistant_app/core/skill/skill_model.dart';

// ─── Shared Council Types ─────────────────────────────────────────────────────

/// A single opinion submitted by an Agent during a council meeting.
class AgentOpinion {
  final String agentId;
  final AgentRoleType role;
  final String content;
  final Map<String, dynamic> structuredData;

  const AgentOpinion({
    required this.agentId,
    required this.role,
    required this.content,
    this.structuredData = const {},
  });
}

/// The agenda item passed to a council meeting.
class CouncilAgenda {
  final String topic;
  final AgendaType type;
  final Map<String, dynamic> context;

  const CouncilAgenda({
    required this.topic,
    required this.type,
    this.context = const {},
  });
}

/// The decision produced by a council meeting.
class CouncilDecision {
  final String summary;
  final List<AgentOpinion> opinions;
  final Map<String, dynamic> actionItems;

  const CouncilDecision({
    required this.summary,
    required this.opinions,
    this.actionItems = const {},
  });
}

enum AgentRoleType {
  principal,      // 校长
  classAdvisor,   // 班主任
  subject,        // 各科老师
  companion,      // 同桌
}

enum AgendaType {
  strategyReview,     // 战略会：制定/调整长期目标
  planScheduling,     // 排课会：协调学科时间分配
  progressReview,     // 进度会：评估当前执行情况
  skillCreation,      // 创建会：讨论新 Skill/Plan 的设计
  emergencyAdjust,    // 紧急调整：同桌触发的快速响应
}

/// Feedback signal emitted by CompanionAgent.
class FeedbackSignal {
  final FeedbackLevel level;
  final String subjectId;
  final String message;
  final Map<String, dynamic> metrics;

  const FeedbackSignal({
    required this.level,
    required this.subjectId,
    required this.message,
    this.metrics = const {},
  });
}

enum FeedbackLevel {
  /// Fast feedback → SubjectAgent (immediate, e.g. error rate spike)
  fast,

  /// Medium feedback → ClassAdvisorAgent (daily, e.g. subject imbalance)
  medium,

  /// Slow feedback → PrincipalAgent (weekly, e.g. overall goal deviation)
  slow,
}

// ─── Agent Role Interfaces ────────────────────────────────────────────────────

/// 校长 — Strategic layer.
/// Owns long-term goals, creates/modifies Plans and Skills based on user
/// feedback. Can dynamically scaffold new Components, Skills, and Tools
/// (analogous to Claude's computer-use capability).
abstract class PrincipalAgent {
  /// Analyse user profile and goals, produce a strategic Plan draft.
  Future<CouncilDecision> formulateStrategy(CouncilAgenda agenda);

  /// Dynamically create a new Skill, Plan, or Component based on user need.
  /// This is the "校长 as system builder" capability — reserved for Phase 3.
  Future<void> scaffoldResource({
    required String resourceType, // 'skill' | 'plan' | 'component' | 'tool'
    required Map<String, dynamic> spec,
  });

  /// Receive a slow-level feedback signal from CompanionAgent and decide
  /// whether to convene a strategy review meeting.
  Future<void> onSlowFeedback(FeedbackSignal signal);
}

/// 班主任 — Planning layer.
/// Translates strategic goals into concrete weekly/daily schedules.
/// Resolves conflicts between subject time allocations.
abstract class ClassAdvisorAgent {
  /// Build a cross-subject schedule from a strategic Plan.
  Future<CouncilDecision> buildSchedule(CouncilAgenda agenda);

  /// Receive medium-level feedback and adjust the current schedule.
  Future<void> onMediumFeedback(FeedbackSignal signal);
}

/// 各科老师 — Execution layer.
/// Executes Subject-Skills for a specific subject.
/// Does not proactively emit feedback; responds to user interactions.
abstract class SubjectAgent {
  final String subjectId;
  const SubjectAgent(this.subjectId);

  /// Execute a Subject-Skill (e.g. Feynman review, spaced repetition).
  Future<SkillExecution> executeSkill(Skill skill, SessionContext session);

  /// Receive fast-level feedback from CompanionAgent and adapt teaching style.
  Future<void> onFastFeedback(FeedbackSignal signal);
}

/// 同桌 — Monitoring layer.
/// Observes learning state in real time and emits tiered feedback signals.
/// Friendly, casual tone — like a real deskmate.
abstract class CompanionAgent {
  /// Observe a completed learning session and emit appropriate feedback signals.
  Future<List<FeedbackSignal>> observe(SessionContext session);

  /// Emit a fast signal directly to the relevant SubjectAgent.
  Future<void> emitFast(FeedbackSignal signal);

  /// Emit a medium signal to ClassAdvisorAgent (batched daily).
  Future<void> emitMedium(FeedbackSignal signal);

  /// Emit a slow signal to PrincipalAgent (batched weekly).
  Future<void> emitSlow(FeedbackSignal signal);
}
