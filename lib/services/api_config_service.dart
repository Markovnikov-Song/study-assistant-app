import 'package:dio/dio.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';

class ApiConfigService {
  final Dio _dio = DioClient.instance.dio;

  /// 安全地将响应数据转为 Map<String, dynamic>
  Map<String, dynamic> _parseResponse(dynamic data, String apiName) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      // 响应是字符串，可能是 HTML 错误或纯文本
      throw ApiException(
        message: '$apiName 失败：服务器返回了非 JSON 数据',
        statusCode: null,
      );
    }
    if (data is List) {
      throw ApiException(
        message: '$apiName 失败：服务器返回了列表而非对象',
        statusCode: null,
      );
    }
    throw ApiException(
      message: '$apiName 失败：无法识别的响应格式（${data.runtimeType}）',
      statusCode: null,
    );
  }

  /// 验证共享配置口令
  Future<Map<String, dynamic>> verifySharedConfig(String passphrase) async {
    try {
      final res = await _dio.post(
        '/api/api-config/verify-shared-config',
        data: {'passphrase': passphrase},
      );
      return _parseResponse(res.data, '验证共享配置');
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
      return _parseResponse(res.data, '保存配置');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取配置状态
  Future<Map<String, dynamic>> getConfigStatus() async {
    try {
      final res = await _dio.get('/api/api-config/config-status');
      return _parseResponse(res.data, '获取配置状态');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 禁用共享配置
  Future<Map<String, dynamic>> disableSharedConfig() async {
    try {
      final res = await _dio.post('/api/api-config/disable-shared-config');
      return _parseResponse(res.data, '禁用共享配置');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 测试 API 连接
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final res = await _dio.get('/api/api-config/test-connection');
      return _parseResponse(res.data, '测试连接');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
