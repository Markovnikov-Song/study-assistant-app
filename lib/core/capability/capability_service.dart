import 'package:dio/dio.dart';

import '../network/dio_client.dart';
import 'capability_models.dart';

class CapabilityService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<CapabilitySummary>> listCapabilities({
    bool? standalone,
    bool? orchestratable,
    bool? schedulable,
    String? category,
    String? kind,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (standalone != null) queryParameters['standalone'] = standalone;
    if (orchestratable != null) {
      queryParameters['orchestratable'] = orchestratable;
    }
    if (schedulable != null) queryParameters['schedulable'] = schedulable;
    if (category != null && category.isNotEmpty) {
      queryParameters['category'] = category;
    }
    if (kind != null && kind.isNotEmpty) queryParameters['kind'] = kind;

    final res = await _dio.get(
      '/api/capabilities',
      queryParameters: queryParameters,
    );
    final data = res.data as Map<String, dynamic>;
    final list = (data['capabilities'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CapabilitySummary.fromJson)
        .where((capability) => capability.id.isNotEmpty)
        .toList();
  }

  Future<CapabilitySummary> composeDraft({
    required String title,
    String? description,
    required String patternId,
    required String adapterId,
  }) async {
    final res = await _dio.post(
      '/api/capabilities/compose-draft',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'pattern_id': patternId,
        'adapter_id': adapterId,
      },
    );
    final data = res.data as Map<String, dynamic>;
    final draft = data['draft'] as Map<String, dynamic>;
    return CapabilitySummary.fromJson(draft);
  }
}
