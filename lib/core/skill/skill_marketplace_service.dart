// lib/core/skill/skill_marketplace_service.dart
// Skill 市场 Service：封装 /api/marketplace/ 系列 API 调用
// 任务 23：Flutter 端 Skill 市场 Service

import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../network/api_exception.dart';
import 'marketplace_models.dart';

class SkillMarketplaceService {
  final Dio _dio = DioClient.instance.dio;

  /// 浏览 Skill 列表，支持过滤和分页。
  /// 需求 6.1、6.2。
  Future<PaginatedSkillList> listSkills({
    String? tag,
    String? keyword,
    String? source,
    String sortBy = 'download_count',
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'sort_by': sortBy,
        'page': page,
      };
      if (tag != null) queryParams['tag'] = tag;
      if (keyword != null) queryParams['keyword'] = keyword;
      if (source != null) queryParams['source'] = source;

      final res = await _dio.get(
        '/api/marketplace/skills',
        queryParameters: queryParams,
      );

      return PaginatedSkillList.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取单个 Skill 完整定义。
  /// 需求 6.1。
  Future<MarketplaceSkill> getSkill(String skillId) async {
    try {
      final res = await _dio.get('/api/marketplace/skills/$skillId');
      return MarketplaceSkill.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 下载云端 Skill 到本地库。
  /// 需求 6.3，属性 11。
  Future<MarketplaceSkill> downloadSkill(String marketplaceSkillId) async {
    try {
      final res = await _dio.post(
        '/api/marketplace/skills/$marketplaceSkillId/download',
      );
      return MarketplaceSkill.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 提交 Skill 到市场（需认证）。
  /// 需求 7.1–7.6。
  Future<MarketplaceSkill> submitSkill(Map<String, dynamic> skillData) async {
    try {
      final res = await _dio.post(
        '/api/marketplace/skills',
        data: skillData,
      );
      return MarketplaceSkill.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
