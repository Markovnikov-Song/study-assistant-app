// Learning OS — Skill Layer
// Core data models for Skills, Sessions, and Agent interactions.
// Phase 1: Data model definitions only — no business logic.

// ─── Enumerations ────────────────────────────────────────────────────────────

enum SkillType {
  /// Provided by the system; cannot be modified or deleted by users.
  builtin,

  /// Created by a user; editable and deletable by its creator.
  custom,
}

enum SkillSource {
  builtin,
  userCreated,
  thirdPartyApi,
  experienceImport,
}

enum LearningMode {
  skillDriver,
  multiSubject,
  diy,
  manual,
}

enum SessionStatus {
  active,
  paused,
  completed,
}

// ─── Skill Models ─────────────────────────────────────────────────────────────

/// A single step in a Skill's Prompt chain.
class PromptNode {
  final String id;

  /// The prompt template for this step.
  final String prompt;

  /// Maps output keys from the previous node to input keys for this node.
  final Map<String, String> inputMapping;

  const PromptNode({
    required this.id,
    required this.prompt,
    this.inputMapping = const {},
  });
}

/// A Skill encapsulates a learning method as a reusable, schedulable unit.
class Skill {
  final String id;
  final String name;
  final String description;
  final List<String> tags;

  /// Ordered list of Prompt nodes — must contain at least one.
  final List<PromptNode> promptChain;

  /// IDs of Components this Skill requires.
  final List<String> requiredComponents;

  final String version;
  final DateTime createdAt;
  final SkillType type;

  /// Creator's user ID — required when [type] is [SkillType.custom].
  final String? createdBy;

  final SkillSource? source;

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    required this.promptChain,
    required this.requiredComponents,
    required this.version,
    required this.createdAt,
    required this.type,
    this.createdBy,
    this.source,
  });
}

/// An in-progress Skill being authored before it is saved to SkillLibrary.
class SkillDraft {
  final String? name;
  final String? description;
  final List<String> tags;
  final List<PromptNode> promptChain;
  final List<String> requiredComponents;

  /// True while the draft has not yet been confirmed and saved.
  final bool isDraft;

  /// Character count of the source text when created via experience-import.
  final int? sourceTextLength;

  const SkillDraft({
    this.name,
    this.description,
    this.tags = const [],
    this.promptChain = const [],
    this.requiredComponents = const [],
    this.isDraft = true,
    this.sourceTextLength,
  });

  static SkillDraft empty() => const SkillDraft();
}

// ─── Session Model ────────────────────────────────────────────────────────────

/// Represents one complete learning session.
class Session {
  final String id;
  final String userId;
  final LearningMode mode;
  final String? skillId;
  final List<String> componentIds;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionStatus status;

  const Session({
    required this.id,
    required this.userId,
    required this.mode,
    this.skillId,
    required this.componentIds,
    required this.startedAt,
    this.endedAt,
    required this.status,
  });
}

// ─── Agent Interaction Models (placeholder) ───────────────────────────────────

/// Context maintained for the duration of a Session.
class SessionContext {
  final String sessionId;
  final String? subjectId;
  final Map<String, dynamic> state;

  const SessionContext({
    required this.sessionId,
    this.subjectId,
    this.state = const {},
  });
}

/// Result returned by AgentKernel.resolveIntent.
class IntentResult {
  final String goal;
  final List<Skill> recommendedSkills;
  final List<String> recommendedComponentIds;

  const IntentResult({
    required this.goal,
    required this.recommendedSkills,
    required this.recommendedComponentIds,
  });
}

/// Represents the execution state of a dispatched Skill.
class SkillExecution {
  final String skillId;
  final int currentNodeIndex;
  final Map<String, dynamic> outputs;

  const SkillExecution({
    required this.skillId,
    required this.currentNodeIndex,
    required this.outputs,
  });
}

/// Data passed to AgentKernel.coordinateComponents for multi-component tasks.
class CoordinationData {
  final String taskType;
  final Map<String, dynamic> payload;

  const CoordinationData({
    required this.taskType,
    required this.payload,
  });
}
