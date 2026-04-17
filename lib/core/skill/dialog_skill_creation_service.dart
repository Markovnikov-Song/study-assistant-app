// lib/core/skill/dialog_skill_creation_service.dart
// 对话式 Skill 创建 Service：封装 /api/agent/dialog-skill/ 系列 API 调用
// 任务 24：Flutter 端对话式创建 Service

import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../network/api_exception.dart';
import 'marketplace_models.dart';
import 'skill_model.dart';

class DialogSkillCreationService {
  final Dio _dio = DioClient.instance.dio;

  /// 启动对话会话，返回第一个引导问题。
  /// 需求 9.1。
  Future<DialogTurn> startSession() async {
    try {
      // 使用空字符串作为 user_id 占位，后端会从 JWT 中获取用户信息
      final res = await _dio.post(
        '/api/agent/dialog-skill/start',
        data: {'user_id': 'current_user'},
      );
      return DialogTurn.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 提交用户回答，返回下一个问题或草稿预览。
  /// 需求 9.2、9.3。
  Future<DialogTurn> sendAnswer(String sessionId, String answer) async {
    try {
      final res = await _dio.post(
        '/api/agent/dialog-skill/$sessionId/answer',
        data: {'answer': answer},
      );
      return DialogTurn.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取当前草稿（支持中断恢复）。
  /// 需求 9.5，属性 15。
  Future<SkillDraft> getDraft(String sessionId) async {
    try {
      final res = await _dio.get(
        '/api/agent/dialog-skill/$sessionId/draft',
      );
      final json = res.data as Map<String, dynamic>;
      final stepsRaw = (json['steps'] as List?) ?? [];
      final steps = stepsRaw.map((node) {
        final n = node as Map<String, dynamic>;
        return PromptNode(
          id: n['id'] as String? ?? '',
          prompt: n['prompt'] as String? ?? '',
          inputMapping: (n['input_mapping'] as Map?)
                  ?.map((k, v) => MapEntry(k as String, v as String)) ??
              const {},
        );
      }).toList();

      return SkillDraft(
        name: json['name'] as String?,
        description: json['description'] as String?,
        tags: ((json['tags'] as List?) ?? []).map((t) => t as String).toList(),
        promptChain: steps,
        requiredComponents: ((json['required_components'] as List?) ?? [])
            .map((c) => c as String)
            .toList(),
        isDraft: json['is_draft'] as bool? ?? true,
        sourceTextLength: (json['source_text_length'] as num?)?.toInt(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 确认草稿，发布为正式 Skill。
  /// 需求 9.4、9.6。
  Future<Skill> confirmAndPublish(String sessionId) async {
    try {
      final res = await _dio.post(
        '/api/agent/dialog-skill/$sessionId/confirm',
      );
      final json = res.data as Map<String, dynamic>;
      final promptChainRaw = (json['prompt_chain'] as List?) ?? [];
      final promptChain = promptChainRaw.map((node) {
        final n = node as Map<String, dynamic>;
        return PromptNode(
          id: n['id'] as String? ?? '',
          prompt: n['prompt'] as String? ?? '',
          inputMapping: (n['input_mapping'] as Map?)
                  ?.map((k, v) => MapEntry(k as String, v as String)) ??
              const {},
        );
      }).toList();

      return Skill(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        tags: ((json['tags'] as List?) ?? []).map((t) => t as String).toList(),
        promptChain: promptChain,
        requiredComponents: ((json['required_components'] as List?) ?? [])
            .map((c) => c as String)
            .toList(),
        version: json['version'] as String? ?? '1.0.0',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        type: SkillType.custom,
        createdBy: json['created_by'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 放弃当前对话会话。
  /// 需求 9.6。
  Future<void> deleteSession(String sessionId) async {
    try {
      await _dio.delete('/api/agent/dialog-skill/$sessionId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
