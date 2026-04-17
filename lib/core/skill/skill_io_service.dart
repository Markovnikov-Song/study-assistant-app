// lib/core/skill/skill_io_service.dart
// Skill JSON 导入导出 Service：封装 /api/agent/skills/export 和 /api/agent/skills/import
// 任务 25：Flutter 端 Skill JSON 导入导出 Service

import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../network/api_exception.dart';
import 'marketplace_models.dart';

class SkillIOService {
  final Dio _dio = DioClient.instance.dio;

  /// 导出 Skill 为 JSON 字符串（含 schema_version）。
  /// 需求 8.1、8.2。
  Future<String> exportSkill(String skillId) async {
    try {
      final res = await _dio.get('/api/agent/skills/$skillId/export');
      final data = res.data as Map<String, dynamic>;
      return data['json_str'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 导入 Skill JSON，返回 SkillImportResult（含缺失 Component 列表）。
  /// 需求 8.4、8.5，属性 13、14。
  Future<SkillImportResult> importSkill(
    String jsonStr,
    List<String> registeredComponents,
  ) async {
    try {
      final res = await _dio.post(
        '/api/agent/skills/import',
        data: {
          'json_str': jsonStr,
          'registered_components': registeredComponents,
        },
      );
      return SkillImportResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
