import 'package:dio/dio.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';

class ApiConfigService {
  final Dio _dio = DioClient.instance.dio;

  /// 验证共享配置口令
  Future<Map<String, dynamic>> verifySharedConfig(String passphrase) async {
    try {
      final res = await _dio.post(
        '/api/api-config/verify-shared-config',
        data: {'passphrase': passphrase},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 保存用户自定义配置
  Future<Map<String, dynamic>> saveCustomConfig({
    String? llmBaseUrl,
    String? llmApiKey,
    String? visionBaseUrl,
    String? visionApiKey,
  }) async {
    try {
      final res = await _dio.post(
        '/api/api-config/save-custom-config',
        data: {
          'llm_base_url': llmBaseUrl,
          'llm_api_key': llmApiKey,
          'vision_base_url': visionBaseUrl,
          'vision_api_key': visionApiKey,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取配置状态
  Future<Map<String, dynamic>> getConfigStatus() async {
    try {
      final res = await _dio.get('/api/api-config/config-status');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 禁用共享配置
  Future<Map<String, dynamic>> disableSharedConfig() async {
    try {
      final res = await _dio.post('/api/api-config/disable-shared-config');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 测试 API 连接
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final res = await _dio.get('/api/api-config/test-connection');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
