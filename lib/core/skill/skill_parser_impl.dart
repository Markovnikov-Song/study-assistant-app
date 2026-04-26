// Learning OS — SkillParser AI Implementation
// Phase 3: Parses unstructured learning experience text into a SkillDraft
// by calling the backend AI service.

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'skill_model.dart';
import 'skill_parser.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_exception.dart';

const _uuid = Uuid();

/// Minimum text length required for parsing (Requirement 8.2.3).
const _kMinTextLength = 50;

/// AI-backed implementation of [SkillParser].
///
/// Calls the backend `/api/skills/parse` endpoint which uses an LLM to
/// extract steps, tools, and timing from the input text.
///
/// Pluggable: swap the backend model by changing the endpoint or injecting
/// a different [SkillParser] implementation (Requirement 8.2.4).
class AiSkillParser implements SkillParser {
  final Dio _dio = DioClient.instance.dio;

  AiSkillParser();

  @override
  Future<SkillDraft> parse(String text) async {
    // Requirement 8.2.3: reject text that is too short or clearly off-topic.
    if (text.trim().length < _kMinTextLength) {
      throw const ParseError(
        '文本太短，无法提取有效步骤。请补充更多内容，或改用对话式创建。',
      );
    }

    try {
      final res = await _dio.post(
        '/api/agent/parse',
        data: {'text': text},
      );

      final data = res.data as Map<String, dynamic>;

      // Backend returns: { name, description, tags, steps: [{prompt, ...}] }
      final rawSteps = (data['steps'] as List?) ?? [];

      if (rawSteps.isEmpty) {
        throw const ParseError(
          '未能从文本中提取到有效的学习步骤。请确认内容与学习方法相关，或改用对话式创建。',
        );
      }

      // Requirement 8.2.6 / Property 14: draft must contain ≥ 1 PromptNode.
      final promptChain = rawSteps.map((step) {
        final s = step as Map<String, dynamic>;
        return PromptNode(
          id: _uuid.v4(),
          prompt: s['prompt'] as String? ?? '',
          inputMapping: (s['input_mapping'] as Map?)
                  ?.map((k, v) => MapEntry(k as String, v as String)) ??
              const {},
        );
      }).toList();

      final tags = ((data['tags'] as List?) ?? [])
          .map((t) => t as String)
          .toList();

      return SkillDraft(
        name: data['name'] as String?,
        description: data['description'] as String?,
        tags: tags,
        promptChain: promptChain,
        requiredComponents: const [],
        isDraft: true,
        sourceTextLength: text.length,
      );
    } on ParseError {
      rethrow;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ParseError('解析失败：$e');
    }
  }
}
