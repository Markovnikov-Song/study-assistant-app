// Learning OS — Agent Kernel (Core)
// AgentKernel is retained as a backward-compatible shim.
// New code should use AgentCouncil (agent_council.dart) directly.
// Phase 1: Interface skeleton only — no business logic.
//
// Upgrade path:
//   AgentKernel (single dispatcher)
//     → AgentCouncil (multi-agent deliberation, see agent_council.dart)

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

/// Backward-compatible single-dispatcher interface.
/// Prefer [AgentCouncil] for new implementations.
abstract class AgentKernel {
  /// Parse the user's natural-language [text] within [session] context and
  /// return up to 3 recommended Skills with rationale, plus suggested
  /// Component IDs. Should complete within 3 seconds.
  Future<IntentResult> resolveIntent(String text, SessionContext session);

  /// Execute [skill] by running its PromptChain nodes in order.
  /// Throws [SkillExecutionError] if any node fails.
  Future<SkillExecution> dispatchSkill(Skill skill, SessionContext session);

  /// Coordinate multiple Components for a composite task.
  Future<void> coordinateComponents(
    List<String> componentIds,
    CoordinationData data,
  );
}
