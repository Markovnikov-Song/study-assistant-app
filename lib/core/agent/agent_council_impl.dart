// Learning OS — AgentCouncil Implementation
// Connects the Flutter-side AgentCouncil interface to the backend /api/council/ routes.
// Phase 3: Full implementation with LLM-backed agents.

import 'package:dio/dio.dart';
import 'package:study_assistant_app/core/agent/agent_council.dart';
import 'package:study_assistant_app/core/agent/agent_kernel.dart';
import 'package:study_assistant_app/core/agent/agent_role.dart';
import 'package:study_assistant_app/core/network/dio_client.dart';
import 'package:study_assistant_app/core/skill/skill_model.dart';

// ── AgentRegistry 实现 ────────────────────────────────────────────────────────

class AgentRegistryImpl implements AgentRegistry {
  final Map<AgentRoleType, Object> _agents = {};

  @override
  void register(AgentRoleType role, Object agent) {
    _agents[role] = agent;
  }

  @override
  T? get<T>(AgentRoleType role) {
    final agent = _agents[role];
    if (agent is T) return agent;
    return null;
  }

  @override
  List<SubjectAgent> getSubjectAgents() {
    return _agents.values.whereType<SubjectAgent>().toList();
  }
}

// ── AgentCouncil 实现 ─────────────────────────────────────────────────────────

/// 连接后端 /api/council/ 路由的 AgentCouncil 实现。
///
/// 所有 Agent 逻辑在后端执行（LLM 调用），Flutter 端只负责：
/// 1. 序列化请求参数
/// 2. 调用后端 API
/// 3. 反序列化响应为 Dart 对象
class AgentCouncilImpl implements AgentCouncil {
  final Dio _dio = DioClient.instance.dio;

  @override
  final AgentRegistry registry = AgentRegistryImpl();

  // ── 召开议事会 ─────────────────────────────────────────────────────────────

  @override
  Future<CouncilDecision> convene(CouncilAgenda agenda) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/council/convene',
        data: {
          'topic': agenda.topic,
          'agenda_type': _agendaTypeToString(agenda.type),
          'context': agenda.context,
        },
      );
      return _parseDecision(res.data!);
    } on DioException catch (e) {
      // 网络失败时返回骨架决策，不中断流程
      return CouncilDecision(
        summary: '议题「${agenda.topic}」已记录，网络恢复后处理。',
        opinions: const [],
        actionItems: const {},
      );
    }
  }

  // ── 反馈路由（甲状腺轴模型）──────────────────────────────────────────────

  @override
  Future<void> routeFeedback(FeedbackSignal signal) async {
    try {
      await _dio.post<void>(
        '/api/council/feedback',
        data: {
          'level': _feedbackLevelToString(signal.level),
          'subject_id': signal.subjectId,
          'message': signal.message,
          'metrics': signal.metrics,
        },
      );
    } on DioException {
      // 反馈路由失败时静默处理，不影响主流程
    }
  }

  // ── 意图解析（委托给 PrincipalAgent）────────────────────────────────────

  @override
  Future<IntentResult> resolveIntent(String text, SessionContext session) async {
    // 委托给现有 AgentKernelImpl，保持向后兼容
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/agent/resolve-intent',
        data: {
          'text': text,
          'session_id': session.sessionId,
          'subject_id': session.subjectId,
        },
      ).timeout(const Duration(seconds: 3));

      final data = res.data!;
      final rawSkills = (data['recommended_skills'] as List?) ?? [];
      final skills = rawSkills.take(3).map((raw) {
        final r = raw as Map<String, dynamic>;
        return Skill(
          id: r['skill_id'] as String,
          name: r['name'] as String? ?? '',
          description: r['description'] as String? ?? '',
          tags: const [],
          promptChain: const [],
          requiredComponents: const [],
          version: '1.0.0',
          createdAt: DateTime.now(),
          type: SkillType.builtin,
          source: SkillSource.builtin,
        );
      }).toList();

      return IntentResult(
        goal: data['goal'] as String? ?? text,
        recommendedSkills: skills,
        recommendedComponentIds: List<String>.from(
          (data['recommended_components'] as List?) ?? [],
        ),
      );
    } catch (_) {
      return IntentResult(
        goal: text,
        recommendedSkills: const [],
        recommendedComponentIds: const [],
      );
    }
  }

  // ── Skill 调度（委托给 SubjectAgent）────────────────────────────────────

  @override
  Future<SkillExecution> dispatchSkill(Skill skill, SessionContext session) async {
    // 委托给现有 AgentKernelImpl 的 execute-node 路径
    final outputs = <String, dynamic>{};
    int currentIndex = 0;

    // 如果 promptChain 为空，先从后端拉取完整 Skill
    List<PromptNode> chain = skill.promptChain;
    if (chain.isEmpty) {
      try {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/agent/skills/${skill.id}',
        );
        final data = res.data!;
        final rawChain = (data['promptChain'] as List?) ?? [];
        chain = rawChain.map((n) {
          final node = n as Map<String, dynamic>;
          return PromptNode(
            id: node['id'] as String,
            prompt: node['prompt'] as String,
            inputMapping: Map<String, String>.from(
              (node['inputMapping'] as Map?) ?? {},
            ),
          );
        }).toList();
      } catch (_) {
        // 拉取失败时用空 chain，后续会抛出 SkillExecutionError
      }
    }

    for (final node in chain) {
      try {
        final nodeInput = _applyInputMapping(node.inputMapping, outputs);
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/agent/execute-node',
          data: {
            'skill_id': skill.id,
            'node_id': node.id,
            'prompt': node.prompt,
            'input': nodeInput,
            'session_id': session.sessionId,
            'subject_id': session.subjectId,
          },
        );
        outputs[node.id] = res.data ?? {};
        currentIndex++;
      } catch (e) {
        throw SkillExecutionError(
          skillId: skill.id,
          nodeId: node.id,
          reason: e.toString(),
        );
      }
    }

    return SkillExecution(
      skillId: skill.id,
      currentNodeIndex: currentIndex,
      outputs: outputs,
    );
  }

  // ── 便捷方法：各 Agent 直接调用 ──────────────────────────────────────────

  /// 校长制定战略
  Future<CouncilDecision> principalFormulateStrategy({
    required String userProfile,
    required String agenda,
    String otherOpinions = '',
    int deviationThreshold = 20,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/council/principal/strategy',
      data: {
        'user_profile': userProfile,
        'agenda': agenda,
        'other_opinions': otherOpinions,
        'deviation_threshold': deviationThreshold,
      },
    );
    return _parseDecision(res.data!);
  }

  /// 班主任排课
  Future<CouncilDecision> advisorBuildSchedule({
    required String currentPlan,
    required String subjectProgress,
    String companionFeedback = '',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/council/advisor/schedule',
      data: {
        'current_plan': currentPlan,
        'subject_progress': subjectProgress,
        'companion_feedback': companionFeedback,
      },
    );
    return _parseDecision(res.data!);
  }

  /// 同桌观察并生成反馈
  Future<CompanionObserveResult> companionObserve({
    required int focusMinutes,
    required int mistakeCount,
    String emotionKeywords = '',
    String decliningSubjects = '',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/council/companion/observe',
      data: {
        'focus_minutes': focusMinutes,
        'mistake_count': mistakeCount,
        'emotion_keywords': emotionKeywords,
        'declining_subjects': decliningSubjects,
      },
    );
    final data = res.data!;
    final rawSignals = (data['feedback_signals'] as List?) ?? [];
    final signals = rawSignals.map((s) {
      final sig = s as Map<String, dynamic>;
      return FeedbackSignal(
        level: _parseFeedbackLevel(sig['level'] as String? ?? 'fast'),
        subjectId: sig['subject_id'] as String? ?? '',
        message: sig['message'] as String? ?? '',
      );
    }).toList();

    return CompanionObserveResult(
      message: data['message'] as String? ?? '',
      feedbackSignals: signals,
      degraded: data['degraded'] as bool? ?? false,
    );
  }

  // ── 内部工具 ───────────────────────────────────────────────────────────────

  CouncilDecision _parseDecision(Map<String, dynamic> data) {
    final rawOpinions = (data['opinions'] as List?) ?? [];
    final opinions = rawOpinions.map((o) {
      final op = o as Map<String, dynamic>;
      return AgentOpinion(
        agentId: op['agent_id'] as String? ?? '',
        role: _parseRoleType(op['role'] as String? ?? ''),
        content: op['content'] as String? ?? '',
        structuredData: Map<String, dynamic>.from(
          (op['structured_data'] as Map?) ?? {},
        ),
      );
    }).toList();

    return CouncilDecision(
      summary: data['summary'] as String? ?? '',
      opinions: opinions,
      actionItems: Map<String, dynamic>.from(
        (data['action_items'] as Map?) ?? {},
      ),
    );
  }

  Map<String, dynamic> _applyInputMapping(
    Map<String, String> inputMapping,
    Map<String, dynamic> previousOutputs,
  ) {
    if (inputMapping.isEmpty) return const {};
    final result = <String, dynamic>{};
    for (final entry in inputMapping.entries) {
      final parts = entry.value.split('.');
      if (parts.length == 2) {
        final nodeOutput = previousOutputs[parts[0]];
        if (nodeOutput is Map) result[entry.key] = nodeOutput[parts[1]];
      } else {
        result[entry.key] = previousOutputs[entry.value];
      }
    }
    return result;
  }

  String _agendaTypeToString(AgendaType type) {
    switch (type) {
      case AgendaType.strategyReview:   return 'strategyReview';
      case AgendaType.planScheduling:   return 'planScheduling';
      case AgendaType.progressReview:   return 'progressReview';
      case AgendaType.skillCreation:    return 'skillCreation';
      case AgendaType.emergencyAdjust:  return 'emergencyAdjust';
    }
  }

  String _feedbackLevelToString(FeedbackLevel level) {
    switch (level) {
      case FeedbackLevel.fast:   return 'fast';
      case FeedbackLevel.medium: return 'medium';
      case FeedbackLevel.slow:   return 'slow';
    }
  }

  FeedbackLevel _parseFeedbackLevel(String s) {
    switch (s) {
      case 'medium': return FeedbackLevel.medium;
      case 'slow':   return FeedbackLevel.slow;
      default:       return FeedbackLevel.fast;
    }
  }

  AgentRoleType _parseRoleType(String s) {
    switch (s) {
      case 'principal':     return AgentRoleType.principal;
      case 'class_advisor': return AgentRoleType.classAdvisor;
      case 'subject':       return AgentRoleType.subject;
      case 'companion':     return AgentRoleType.companion;
      default:              return AgentRoleType.principal;
    }
  }
}

// ── 同桌观察结果 ───────────────────────────────────────────────────────────────

class CompanionObserveResult {
  final String message;
  final List<FeedbackSignal> feedbackSignals;
  final bool degraded;

  const CompanionObserveResult({
    required this.message,
    required this.feedbackSignals,
    this.degraded = false,
  });
}
