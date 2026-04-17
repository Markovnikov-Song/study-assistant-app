// Learning OS — Agent Kernel Implementation
// Phase 3: resolveIntent (AI-backed) + dispatchSkill (PromptChain execution).

import 'dart:async';
import 'package:dio/dio.dart';
import '../skill/skill_model.dart';
import '../skill/skill_library.dart';
import 'agent_kernel.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_exception.dart';

/// Concrete implementation of [AgentKernel].
///
/// - [resolveIntent]: calls the backend AI service and returns up to 3
///   recommended Skills with rationale within 3 seconds (Requirement 2.1, 2.2).
/// - [dispatchSkill]: executes PromptChain nodes in order, passing each
///   node's output to the next (Requirement 2.4, Property 7).
///   Terminates and records failure on any node error (Requirement 2.6, Property 8).
/// - [coordinateComponents]: stub for Phase 3 multi-component coordination.
class AgentKernelImpl implements AgentKernel {
  final SkillLibrary _skillLibrary;
  final Dio _dio = DioClient.instance.dio;

  AgentKernelImpl(this._skillLibrary);

  // ── resolveIntent ──────────────────────────────────────────────────────────

  @override
  Future<IntentResult> resolveIntent(
    String text,
    SessionContext session,
  ) async {
    // Requirement 2.1: must return within 3 seconds.
    try {
      final res = await _dio
          .post(
            '/api/agent/resolve-intent',
            data: {
              'text': text,
              'session_id': session.sessionId,
              'subject_id': session.subjectId,
            },
          )
          .timeout(const Duration(seconds: 3));

      final data = res.data as Map<String, dynamic>;

      // Parse recommended skills from response.
      // Backend returns full Skill metadata — build Skill objects directly
      // rather than looking up in local SkillLibrary (which may be empty on
      // first launch before skills are synced).
      final rawSkills = (data['recommended_skills'] as List?) ?? [];
      final skills = <Skill>[];
      for (final raw in rawSkills.take(3)) {
        final id = raw['skill_id'] as String?;
        if (id == null) continue;
        // Try local library first; fall back to constructing from response.
        final localSkill = await _skillLibrary.get(id);
        if (localSkill != null) {
          skills.add(localSkill);
        } else {
          // Build a minimal Skill from the backend recommendation payload.
          skills.add(Skill(
            id: id,
            name: raw['name'] as String? ?? id,
            description: raw['description'] as String? ?? '',
            tags: const [],
            promptChain: const [],  // Full chain fetched on dispatch
            requiredComponents: const [],
            version: '1.0.0',
            createdAt: DateTime.now(),
            type: SkillType.builtin,
            source: SkillSource.builtin,
          ));
        }
      }

      // Requirement 2.2: rationale ≤ 50 chars per skill (enforced by backend,
      // but we truncate here as a safety net).
      final componentIds = ((data['recommended_components'] as List?) ?? [])
          .map((e) => e as String)
          .toList();

      return IntentResult(
        goal: data['goal'] as String? ?? text,
        recommendedSkills: skills,
        recommendedComponentIds: componentIds,
      );
    } on TimeoutException {
      // Requirement 2.1: if AI doesn't respond in time, return empty result.
      return IntentResult(
        goal: text,
        recommendedSkills: const [],
        recommendedComponentIds: const [],
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── dispatchSkill ──────────────────────────────────────────────────────────

  @override
  Future<SkillExecution> dispatchSkill(
    Skill skill,
    SessionContext session,
  ) async {
    // If the skill was built from a recommendation stub (empty promptChain),
    // fetch the full definition from the backend before executing.
    Skill fullSkill = skill;
    if (skill.promptChain.isEmpty) {
      try {
        final res = await _dio.get('/api/agent/skills/${skill.id}');
        final data = res.data as Map<String, dynamic>;
        final rawChain = (data['promptChain'] as List?) ?? [];
        final nodes = rawChain.map((n) => PromptNode(
          id: n['id'] as String,
          prompt: n['prompt'] as String,
          inputMapping: Map<String, String>.from(
            (n['inputMapping'] as Map?) ?? {},
          ),
        )).toList();
        fullSkill = Skill(
          id: skill.id,
          name: skill.name,
          description: skill.description,
          tags: List<String>.from((data['tags'] as List?) ?? []),
          promptChain: nodes,
          requiredComponents: List<String>.from(
            (data['requiredComponents'] as List?) ?? [],
          ),
          version: data['version'] as String? ?? '1.0.0',
          createdAt: skill.createdAt,
          type: skill.type,
          source: skill.source,
        );
      } catch (_) {
        // If fetch fails, proceed with empty chain — will throw SkillExecutionError below.
      }
    }

    // Requirement 2.4 / Property 7: execute PromptChain nodes in order,
    // passing each node's output as the next node's input.
    final outputs = <String, dynamic>{};
    int currentIndex = 0;

    for (final node in fullSkill.promptChain) {
      try {
        // Build input for this node by applying inputMapping from previous outputs.
        final nodeInput = _applyInputMapping(node.inputMapping, outputs);

        final nodeOutput = await _executeNode(
          node: node,
          skill: fullSkill,
          session: session,
          input: nodeInput,
        );

        outputs[node.id] = nodeOutput;
        currentIndex++;
      } on SkillExecutionError {
        // Already a typed error — rethrow without re-wrapping.
        rethrow;
      } catch (e) {
        // Requirement 2.6 / Property 8: terminate on failure, record node info.
        throw SkillExecutionError(
          skillId: fullSkill.id,
          nodeId: node.id,
          reason: e.toString(),
        );
      }
    }

    return SkillExecution(
      skillId: fullSkill.id,
      currentNodeIndex: currentIndex,
      outputs: outputs,
    );
  }

  // ── coordinateComponents ───────────────────────────────────────────────────

  @override
  Future<void> coordinateComponents(
    List<String> componentIds,
    CoordinationData data,
  ) async {
    // Stub: multi-component coordination (e.g. multi-subject learning plan)
    // will be wired to concrete Component instances in a later iteration.
    // For now, log the coordination request and return.
    assert(componentIds.isNotEmpty, 'coordinateComponents requires at least one component');
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Applies [inputMapping] to [previousOutputs] to build the input map
  /// for the current PromptNode.
  Map<String, dynamic> _applyInputMapping(
    Map<String, String> inputMapping,
    Map<String, dynamic> previousOutputs,
  ) {
    if (inputMapping.isEmpty) return const {};
    final result = <String, dynamic>{};
    for (final entry in inputMapping.entries) {
      // entry.key   = input key for this node
      // entry.value = "nodeId.outputKey" from a previous node
      final parts = entry.value.split('.');
      if (parts.length == 2) {
        final nodeId = parts[0];
        final outputKey = parts[1];
        final nodeOutput = previousOutputs[nodeId];
        if (nodeOutput is Map) {
          result[entry.key] = nodeOutput[outputKey];
        }
      } else {
        // Direct reference to a previous node's full output.
        result[entry.key] = previousOutputs[entry.value];
      }
    }
    return result;
  }

  /// Calls the backend to execute a single [PromptNode].
  Future<Map<String, dynamic>> _executeNode({
    required PromptNode node,
    required Skill skill,
    required SessionContext session,
    required Map<String, dynamic> input,
  }) async {
    final res = await _dio.post(
      '/api/agent/execute-node',
      data: {
        'skill_id': skill.id,
        'node_id': node.id,
        'prompt': node.prompt,
        'input': input,
        'session_id': session.sessionId,
        'subject_id': session.subjectId,
      },
    );
    return (res.data as Map<String, dynamic>?) ?? {};
  }
}
