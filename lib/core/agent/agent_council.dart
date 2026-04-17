// Learning OS — AgentCouncil
// The council is the multi-agent deliberation mechanism.
// Agents "convene" around an agenda, submit opinions, and produce a decision.
// Phase 1: Interface skeleton only — no business logic.
//
// Upgrade path from AgentKernel:
//   AgentKernel (single dispatcher) → AgentCouncil (multi-agent deliberation)
//   AgentKernel is retained as a compatibility shim pointing to AgentCouncil.

import 'package:study_assistant_app/core/agent/agent_role.dart';
import 'package:study_assistant_app/core/skill/skill_model.dart';

/// Registry of all active Agents in the council.
/// Agents are registered by role type; multiple SubjectAgents can coexist.
abstract class AgentRegistry {
  /// Register an agent under its role type.
  void register(AgentRoleType role, Object agent);

  /// Retrieve the agent for a given role. Returns null if not registered.
  T? get<T>(AgentRoleType role);

  /// Retrieve all SubjectAgents (one per subject).
  List<SubjectAgent> getSubjectAgents();
}

/// The council orchestrates multi-agent meetings and routes feedback signals.
///
/// Meeting flow:
///   1. Caller invokes [convene] with an [CouncilAgenda].
///   2. Council determines which agents should attend based on agenda type.
///   3. Each attending agent submits an [AgentOpinion].
///   4. Council synthesises opinions into a [CouncilDecision].
///   5. Decision is returned to the caller (and optionally stored in Session).
///
/// Feedback routing (thyroid-axis model):
///   CompanionAgent emits FeedbackSignal →
///     fast   → SubjectAgent.onFastFeedback()
///     medium → ClassAdvisorAgent.onMediumFeedback()  [may trigger small meeting]
///     slow   → PrincipalAgent.onSlowFeedback()       [may trigger strategy review]
abstract class AgentCouncil {
  /// The agent registry — all participants are looked up here.
  AgentRegistry get registry;

  /// Convene a meeting around [agenda].
  /// Returns the synthesised [CouncilDecision].
  /// Phase 1: returns a stub decision.
  Future<CouncilDecision> convene(CouncilAgenda agenda);

  /// Route a [FeedbackSignal] from CompanionAgent to the appropriate agent(s).
  /// Phase 1: no-op stub.
  Future<void> routeFeedback(FeedbackSignal signal);

  /// Resolve user intent — delegates to PrincipalAgent.
  /// Replaces AgentKernel.resolveIntent for backward compatibility.
  Future<IntentResult> resolveIntent(String text, SessionContext session);

  /// Dispatch a Skill — delegates to the appropriate SubjectAgent.
  /// Replaces AgentKernel.dispatchSkill for backward compatibility.
  Future<SkillExecution> dispatchSkill(Skill skill, SessionContext session);
}
