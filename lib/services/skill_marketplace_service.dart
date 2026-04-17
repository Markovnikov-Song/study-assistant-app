// Learning OS — Skill Marketplace Service
// Phase 3: Skeleton endpoints for the open Skill Marketplace API.
// Requirement 8.3.1: POST /api/skills, GET /api/skills, GET /api/skills/{id}
// Each endpoint returns a fixed placeholder response at this stage.

import 'package:dio/dio.dart';
import '../core/skill/skill_model.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_exception.dart';

/// Placeholder response returned by all Marketplace endpoints in Phase 3.
class MarketplaceResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  const MarketplaceResponse({
    required this.success,
    required this.message,
    this.data,
  });
}

/// Client for the Skill Marketplace open API.
///
/// All three endpoints are skeleton stubs that return fixed placeholder
/// responses (Requirement 8.3.1). Business logic will be filled in a
/// future iteration.
class SkillMarketplaceService {
  // _dio is reserved for future use when placeholder responses are replaced
  // with real backend calls.
  // ignore: unused_field
  final Dio _dio = DioClient.instance.dio;

  // ── POST /api/skills ───────────────────────────────────────────────────────

  /// Submit a Skill to the Marketplace.
  ///
  /// Requirement 8.3.4: validates the Skill structure before submission.
  /// Currently returns a fixed placeholder response.
  Future<MarketplaceResponse> submitSkill(Skill skill) async {
    try {
      // Structural validation (same rules as Requirement 1).
      if (skill.promptChain.isEmpty) {
        return const MarketplaceResponse(
          success: false,
          message: 'Skill validation failed: promptChain is empty',
        );
      }

      // Placeholder: in production this would POST to the backend.
      // await _dio.post('/api/skills', data: _skillToJson(skill));
      return MarketplaceResponse(
        success: true,
        message: 'Skill submitted successfully (placeholder)',
        data: {'skill_id': skill.id},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── GET /api/skills ────────────────────────────────────────────────────────

  /// Query the Marketplace Skill list.
  ///
  /// Requirement 8.3.5: supports filtering by source type.
  /// Currently returns a fixed empty list placeholder.
  Future<MarketplaceResponse> listSkills({
    SkillSource? source,
    String? nameKeyword,
    List<String>? tags,
  }) async {
    try {
      // Placeholder: in production this would GET /api/skills with query params.
      return const MarketplaceResponse(
        success: true,
        message: 'Marketplace listing (placeholder)',
        data: {'skills': [], 'total': 0},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── GET /api/skills/{id} ───────────────────────────────────────────────────

  /// Retrieve a single Skill from the Marketplace by [skillId].
  ///
  /// Currently returns a fixed placeholder response.
  Future<MarketplaceResponse> getSkill(String skillId) async {
    try {
      // Placeholder: in production this would GET /api/skills/{skillId}.
      return MarketplaceResponse(
        success: true,
        message: 'Skill detail (placeholder)',
        data: {'skill_id': skillId, 'detail': null},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
