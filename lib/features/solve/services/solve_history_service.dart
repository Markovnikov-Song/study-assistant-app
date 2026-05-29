import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/storage_service.dart';
import '../models/solve_session.dart';

/// 解题历史 REST API 客户端
///
/// 对应后端路由 /api/solve/sessions
class SolveHistoryService {
  Dio get _dio => DioClient.instance.dio;

  /// 获取当前用户的所有解题历史会话列表（按创建时间降序）
  ///
  /// GET /api/solve/sessions
  Future<List<SolveHistorySession>> fetchSessions() async {
    final token = await StorageService.instance.getToken() ?? '';
    final response = await _dio.get<List<dynamic>>(
      '/api/solve/sessions',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final data = response.data ?? [];
    return data
        .cast<Map<String, dynamic>>()
        .map(SolveHistorySession.fromJson)
        .toList();
  }

  /// 获取指定会话的完整历史消息列表
  ///
  /// GET /api/solve/sessions/{sessionId}
  Future<List<SolveHistoryMessage>> fetchSession(int sessionId) async {
    final token = await StorageService.instance.getToken() ?? '';
    final response = await _dio.get<List<dynamic>>(
      '/api/solve/sessions/$sessionId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final data = response.data ?? [];
    return data
        .cast<Map<String, dynamic>>()
        .map(SolveHistoryMessage.fromJson)
        .toList();
  }

  /// 删除指定会话（级联删除历史消息）
  ///
  /// DELETE /api/solve/sessions/{sessionId}
  Future<void> deleteSession(int sessionId) async {
    final token = await StorageService.instance.getToken() ?? '';
    await _dio.delete(
      '/api/solve/sessions/$sessionId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }
}
