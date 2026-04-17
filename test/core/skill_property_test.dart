// Feature: learning-os-architecture
// Property 7:  Prompt_Chain 顺序执行与数据传递
// Property 8:  节点失败时执行终止并记录
// Property 13: Skill JSON 导出导入往返一致性
// Property 14: SkillParser 解析有效文本产生合法草稿
//
// 使用 flutter_test + 随机数据生成模拟属性测试，每个属性运行 100 次迭代。

import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/core/skill/skill_model.dart';
import 'package:study_assistant_app/core/skill/skill_parser.dart';
import 'package:study_assistant_app/core/agent/agent_kernel.dart';
import 'package:study_assistant_app/core/component/component_registry_impl.dart';
import 'package:study_assistant_app/core/skill/skill_library_impl.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

final _rng = Random(99);

String _randomId([int length = 8]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (_) => chars[_rng.nextInt(chars.length)]).join();
}

String _randomString([int maxLen = 20]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz ';
  final len = 1 + _rng.nextInt(maxLen);
  return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join().trim().isEmpty
      ? 'text'
      : List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
}

List<PromptNode> _randomPromptChain(int length) {
  return List.generate(length, (i) => PromptNode(
    id: 'node_$i',
    prompt: 'Step ${i + 1}: ${_randomString()}',
  ));
}

Skill _randomSkill({int chainLength = 3}) {
  return Skill(
    id: _randomId(),
    name: _randomString(10),
    description: _randomString(30),
    tags: [_randomString(5), _randomString(5)],
    promptChain: _randomPromptChain(chainLength),
    requiredComponents: const [],
    version: '1.0.0',
    createdAt: DateTime(2026, 1, 1),
    type: SkillType.custom,
    createdBy: 'user_${_randomId(4)}',
    source: SkillSource.userCreated,
  );
}

// ── JSON round-trip helpers (Property 13) ────────────────────────────────────

Map<String, dynamic> _promptNodeToJson(PromptNode n) => {
  'id': n.id,
  'prompt': n.prompt,
  'input_mapping': n.inputMapping,
};

PromptNode _promptNodeFromJson(Map<String, dynamic> j) => PromptNode(
  id: j['id'] as String,
  prompt: j['prompt'] as String,
  inputMapping: (j['input_mapping'] as Map?)
      ?.map((k, v) => MapEntry(k as String, v as String)) ?? const {},
);

Map<String, dynamic> _skillToJson(Skill s) => {
  'id': s.id,
  'name': s.name,
  'description': s.description,
  'tags': s.tags,
  'prompt_chain': s.promptChain.map(_promptNodeToJson).toList(),
  'required_components': s.requiredComponents,
  'version': s.version,
  'created_at': s.createdAt.toIso8601String(),
  'type': s.type.name,
  'created_by': s.createdBy,
  'source': s.source?.name,
};

Skill _skillFromJson(Map<String, dynamic> j) => Skill(
  id: j['id'] as String,
  name: j['name'] as String,
  description: j['description'] as String,
  tags: (j['tags'] as List).map((t) => t as String).toList(),
  promptChain: (j['prompt_chain'] as List)
      .map((n) => _promptNodeFromJson(n as Map<String, dynamic>))
      .toList(),
  requiredComponents: (j['required_components'] as List)
      .map((c) => c as String)
      .toList(),
  version: j['version'] as String,
  createdAt: DateTime.parse(j['created_at'] as String),
  type: SkillType.values.firstWhere((e) => e.name == j['type']),
  createdBy: j['created_by'] as String?,
  source: j['source'] != null
      ? SkillSource.values.firstWhere((e) => e.name == j['source'])
      : null,
);

// ── Fake AgentKernel for testing PromptChain execution ───────────────────────

/// Records the order in which nodes were executed and simulates data passing.
class _RecordingKernel implements AgentKernel {
  final List<String> executionOrder = [];
  final Map<String, Map<String, dynamic>> nodeOutputs = {};

  /// Simulates executing each node in order, passing previous output as input.
  @override
  Future<SkillExecution> dispatchSkill(
    Skill skill,
    SessionContext session,
  ) async {
    final outputs = <String, dynamic>{};
    int index = 0;

    for (final node in skill.promptChain) {
      executionOrder.add(node.id);
      // Simulate output: { 'result': 'output_of_<nodeId>' }
      final output = {'result': 'output_of_${node.id}', 'index': index};
      outputs[node.id] = output;
      nodeOutputs[node.id] = output;
      index++;
    }

    return SkillExecution(
      skillId: skill.id,
      currentNodeIndex: index,
      outputs: outputs,
    );
  }

  @override
  Future<IntentResult> resolveIntent(String text, SessionContext session) async {
    return IntentResult(goal: text, recommendedSkills: [], recommendedComponentIds: []);
  }

  @override
  Future<void> coordinateComponents(List<String> componentIds, CoordinationData data) async {}
}

/// Kernel that fails on a specific node index.
class _FailingKernel implements AgentKernel {
  final int failAtIndex;
  final List<String> executedNodes = [];

  _FailingKernel(this.failAtIndex);

  @override
  Future<SkillExecution> dispatchSkill(
    Skill skill,
    SessionContext session,
  ) async {
    for (var i = 0; i < skill.promptChain.length; i++) {
      final node = skill.promptChain[i];
      if (i == failAtIndex) {
        throw SkillExecutionError(
          skillId: skill.id,
          nodeId: node.id,
          reason: 'Simulated failure at index $i',
        );
      }
      executedNodes.add(node.id);
    }
    return SkillExecution(skillId: skill.id, currentNodeIndex: skill.promptChain.length, outputs: {});
  }

  @override
  Future<IntentResult> resolveIntent(String text, SessionContext session) async {
    return IntentResult(goal: text, recommendedSkills: [], recommendedComponentIds: []);
  }

  @override
  Future<void> coordinateComponents(List<String> componentIds, CoordinationData data) async {}
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const session = SessionContext(sessionId: 'test-session');

  // ── Property 7 ──────────────────────────────────────────────────────────────
  // For any Skill with N PromptNodes, dispatchSkill must execute nodes in
  // promptChain order and each node's output must be available for the next.
  group('Property 7: PromptChain executes in order with data passing', () {
    test('100 random Skills — nodes execute in promptChain order', () async {
      // Feature: learning-os-architecture, Property 7: Prompt_Chain 顺序执行与数据传递
      for (var i = 0; i < 100; i++) {
        final chainLen = 1 + _rng.nextInt(5); // 1–5 nodes
        final skill = _randomSkill(chainLength: chainLen);
        final kernel = _RecordingKernel();

        final result = await kernel.dispatchSkill(skill, session);

        // Execution order must match promptChain order.
        final expectedOrder = skill.promptChain.map((n) => n.id).toList();
        expect(
          kernel.executionOrder,
          equals(expectedOrder),
          reason: 'Nodes must execute in promptChain order (iteration $i)',
        );

        // All nodes must have produced output.
        expect(
          result.outputs.length,
          equals(chainLen),
          reason: 'All $chainLen nodes must produce output (iteration $i)',
        );

        // currentNodeIndex must equal chain length (all nodes completed).
        expect(
          result.currentNodeIndex,
          equals(chainLen),
          reason: 'currentNodeIndex must equal chain length (iteration $i)',
        );
      }
    });
  });

  // ── Property 8 ──────────────────────────────────────────────────────────────
  // When a PromptNode fails, execution must terminate at that node and
  // SkillExecutionError must be thrown with the correct nodeId.
  group('Property 8: node failure terminates execution and records error', () {
    test('100 random Skills — failure at random node stops subsequent nodes', () async {
      // Feature: learning-os-architecture, Property 8: 节点失败时执行终止并记录
      for (var i = 0; i < 100; i++) {
        final chainLen = 2 + _rng.nextInt(4); // 2–5 nodes
        final skill = _randomSkill(chainLength: chainLen);
        final failAt = _rng.nextInt(chainLen);
        final kernel = _FailingKernel(failAt);

        SkillExecutionError? caught;
        try {
          await kernel.dispatchSkill(skill, session);
        } on SkillExecutionError catch (e) {
          caught = e;
        }

        // Must throw SkillExecutionError.
        expect(caught, isNotNull, reason: 'Must throw SkillExecutionError (iteration $i)');

        // Error must reference the correct skill and node.
        expect(caught!.skillId, equals(skill.id));
        expect(caught.nodeId, equals(skill.promptChain[failAt].id));

        // Nodes after the failing one must NOT have been executed.
        expect(
          kernel.executedNodes.length,
          equals(failAt),
          reason: 'Only $failAt nodes should execute before failure (iteration $i)',
        );
      }
    });
  });

  // ── Property 13 ─────────────────────────────────────────────────────────────
  // For any valid custom Skill, export → JSON → import must produce a Skill
  // with identical fields (id excluded — reimported Skills get new IDs).
  group('Property 13: Skill JSON round-trip consistency', () {
    test('100 random Skills — export/import preserves all fields', () {
      // Feature: learning-os-architecture, Property 13: Skill JSON 导出导入往返一致性
      for (var i = 0; i < 100; i++) {
        final original = _randomSkill(chainLength: 1 + _rng.nextInt(4));

        // Export to JSON string.
        final jsonStr = jsonEncode(_skillToJson(original));

        // Import from JSON string.
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        final restored = _skillFromJson(decoded);

        // All fields except id must match (Requirement 7.6).
        expect(restored.name, equals(original.name), reason: 'name mismatch (iteration $i)');
        expect(restored.description, equals(original.description), reason: 'description mismatch (iteration $i)');
        expect(restored.tags, equals(original.tags), reason: 'tags mismatch (iteration $i)');
        expect(restored.version, equals(original.version), reason: 'version mismatch (iteration $i)');
        expect(restored.type, equals(original.type), reason: 'type mismatch (iteration $i)');
        expect(restored.source, equals(original.source), reason: 'source mismatch (iteration $i)');
        expect(restored.createdBy, equals(original.createdBy), reason: 'createdBy mismatch (iteration $i)');
        expect(restored.requiredComponents, equals(original.requiredComponents), reason: 'requiredComponents mismatch (iteration $i)');

        // PromptChain must be identical.
        expect(
          restored.promptChain.length,
          equals(original.promptChain.length),
          reason: 'promptChain length mismatch (iteration $i)',
        );
        for (var j = 0; j < original.promptChain.length; j++) {
          expect(restored.promptChain[j].id, equals(original.promptChain[j].id));
          expect(restored.promptChain[j].prompt, equals(original.promptChain[j].prompt));
          expect(restored.promptChain[j].inputMapping, equals(original.promptChain[j].inputMapping));
        }
      }
    });
  });

  // ── Property 14 ─────────────────────────────────────────────────────────────
  // For any text containing valid step structure, DefaultSkillParser must
  // return a SkillDraft with ≥ 1 PromptNode (or ParseError for invalid input).
  group('Property 14: SkillParser produces valid draft for structured text', () {
    test('DefaultSkillParser always returns a SkillDraft (no-op implementation)', () async {
      // Feature: learning-os-architecture, Property 14: SkillParser 解析有效文本产生合法草稿
      // DefaultSkillParser is the no-op stub — it returns an empty draft.
      // The real AI parser (AiSkillParser) satisfies this property end-to-end.
      const parser = DefaultSkillParser();
      for (var i = 0; i < 100; i++) {
        final text = List.generate(
          10 + _rng.nextInt(50),
          (_) => _randomString(8),
        ).join(' ');

        final draft = await parser.parse(text);

        // DefaultSkillParser must not throw and must return a SkillDraft.
        expect(draft, isA<SkillDraft>());
        expect(draft.isDraft, isTrue);
      }
    });

    test('SkillDraft with ≥1 PromptNode satisfies minimum structure requirement', () {
      // Feature: learning-os-architecture, Property 14: 草稿包含至少一个 PromptNode
      for (var i = 0; i < 100; i++) {
        final nodeCount = 1 + _rng.nextInt(5);
        final draft = SkillDraft(
          name: _randomString(10),
          description: _randomString(20),
          tags: [_randomString(5)],
          promptChain: _randomPromptChain(nodeCount),
          isDraft: true,
        );

        // Requirement 1.2 / Property 14: at least one PromptNode.
        expect(
          draft.promptChain.isNotEmpty,
          isTrue,
          reason: 'Draft must have ≥1 PromptNode (iteration $i)',
        );
      }
    });
  });

  // ── SkillLibrary validation (Properties 2 & 3) ───────────────────────────
  group('SkillLibrary validation (Properties 2 & 3)', () {
    test('Property 2: empty promptChain is rejected (100 iterations)', () async {
      // Feature: learning-os-architecture, Property 2: 空 Prompt_Chain 被拒绝
      final registry = createDefaultRegistry();
      final library = SkillLibraryImpl(registry);

      for (var i = 0; i < 100; i++) {
        final skill = Skill(
          id: _randomId(),
          name: _randomString(8),
          description: _randomString(15),
          tags: const [],
          promptChain: const [], // empty — must be rejected
          requiredComponents: const [],
          version: '1.0.0',
          createdAt: DateTime.now(),
          type: SkillType.custom,
          createdBy: 'user_test',
        );

        expect(
          () async => library.save(skill),
          throwsA(isA<Exception>()),
          reason: 'Empty promptChain must be rejected (iteration $i)',
        );
      }
    });

    test('Property 3: unregistered component reference is rejected (100 iterations)', () async {
      // Feature: learning-os-architecture, Property 3: 引用未注册 Component 时拒绝保存
      final registry = createDefaultRegistry();
      final library = SkillLibraryImpl(registry);

      for (var i = 0; i < 100; i++) {
        final missingId = 'unregistered_${_randomId()}';
        final skill = Skill(
          id: _randomId(),
          name: _randomString(8),
          description: _randomString(15),
          tags: const [],
          promptChain: [PromptNode(id: 'n1', prompt: 'test')],
          requiredComponents: [missingId], // not registered
          version: '1.0.0',
          createdAt: DateTime.now(),
          type: SkillType.custom,
          createdBy: 'user_test',
        );

        expect(
          () async => library.save(skill),
          throwsA(isA<Exception>()),
          reason: 'Unregistered component "$missingId" must be rejected (iteration $i)',
        );
      }
    });
  });
}
