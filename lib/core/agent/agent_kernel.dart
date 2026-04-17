// Learning OS — Agent Kernel (Core)
// AgentKernel is the central dispatcher: it resolves user intent, schedules
// Skills, and coordinates Components to fulfil learning tasks.
// Phase 1: Interface skeleton only — no business logic.

import 'package:study_assistant_app/core/skill/skill_model.dart';

/// Thrown when a PromptNode fails during Skill execution.
class SkillExecutionError implements Exception {
  final String skillId;
  final String nodeId;
  final String reason;

  const SkillExecutionError({
    required this.skillId,
    required this.nodeId,
    required this.reason,
  });

  @override
  String toString() =>
      'SkillExecutionError: skill "$skillId", node "$nodeId" — $reason';
}

/// The central intelligence of Learning OS.
/// Resolves natural-language intent, dispatches Skills, and coordinates
/// multi-Component tasks (e.g. multi-subject learning plans).
abstract class AgentKernel {
  /// Parse the user's natural-language [text] within [session] context and
  /// return up to 3 recommended Skills with rationale, plus suggested
  /// Component IDs.
  /// Should complete within 3 seconds.
  Future<IntentResult> resolveIntent(String text, SessionContext session);

  /// Execute [skill] by running its PromptChain nodes in order, passing each
  /// node's output as the next node's input.
  /// Throws [SkillExecutionError] if any node fails; execution stops at the
  /// failing node and subsequent nodes are not called.
  Future<SkillExecution> dispatchSkill(Skill skill, SessionContext session);

  /// Coordinate multiple Components identified by [componentIds] to complete
  /// a composite task described by [data] (e.g. generate a multi-subject
  /// learning plan and push it to the Calendar Component).
  Future<void> coordinateComponents(
    List<String> componentIds,
    CoordinationData data,
  );
}
