import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';
import 'mini_app_models.dart';

class MiniAppService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<MiniAppSummary>> listApps() async {
    try {
      final res = await _dio.get('/api/mini-apps');
      final data = res.data as Map<String, dynamic>;
      final list = (data['apps'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MiniAppSummary.fromJson)
          .where((app) => app.id.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MiniAppRecord> getApp(String id) async {
    try {
      final res = await _dio.get('/api/mini-apps/$id');
      return MiniAppRecord.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteApp(String id) async {
    try {
      await _dio.delete('/api/mini-apps/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MiniAppRecord> updateApp({
    required String id,
    String? title,
    Map<String, String>? documents,
    Map<String, dynamic>? spec,
    String? status,
  }) async {
    try {
      final res = await _dio.put(
        '/api/mini-apps/$id',
        data: {
          ...?title == null ? null : {'title': title},
          ...?documents == null ? null : {'documents': documents},
          ...?spec == null ? null : {'spec': spec},
          ...?status == null ? null : {'status': status},
        },
      );
      final data = res.data as Map<String, dynamic>;
      return MiniAppRecord.fromJson(
        (data['app'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MiniAppRecord> reviseApp({
    required String id,
    required String instruction,
  }) async {
    try {
      final res = await _dio.post(
        '/api/mini-apps/$id/revise',
        data: {'instruction': instruction},
      );
      final data = res.data as Map<String, dynamic>;
      return MiniAppRecord.fromJson(
        (data['app'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> getBlockRegistry() async {
    try {
      final res = await _dio.get('/api/mini-apps/blocks');
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MiniAppValidation> validateGraph({
    required Map<String, dynamic> graph,
    Map<String, dynamic>? spec,
  }) async {
    try {
      final res = await _dio.post(
        '/api/mini-apps/graph/validate',
        data: {
          'graph': graph,
          ...?spec == null ? null : {'spec': spec},
        },
      );
      return MiniAppValidation.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> previewGraph(String id) async {
    try {
      final res = await _dio.post('/api/mini-apps/$id/graph/preview');
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> startRun(String appId) async {
    try {
      final res = await _dio.post('/api/mini-apps/$appId/runs/start');
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> appendRunEvent({
    required String runId,
    required String nodeId,
    required String eventType,
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      final res = await _dio.post(
        '/api/mini-apps/runs/$runId/events',
        data: {'node_id': nodeId, 'event_type': eventType, 'payload': payload},
      );
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MiniAppInterviewTurn> startInterview({
    required String initialRequest,
    int? subjectId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/mini-apps/interview/start',
        data: {
          'initial_request': initialRequest,
          ...?subjectId == null ? null : {'subject_id': subjectId},
        },
      );
      return MiniAppInterviewTurn.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<GenerateCardsResult> generateCardsForApp({
    required String appId,
    List<int> documentIds = const [],
    bool useLlm = true,
  }) async {
    try {
      final res = await _dio.post(
        '/api/mini-apps/$appId/generate-cards',
        data: {'document_ids': documentIds, 'use_llm': useLlm},
      );
      return GenerateCardsResult.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MiniAppInterviewTurn> answerInterview({
    required String sessionId,
    required String answer,
  }) async {
    try {
      final res = await _dio.post(
        '/api/mini-apps/interview/$sessionId/answer',
        data: {'answer': answer},
      );
      return MiniAppInterviewTurn.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
