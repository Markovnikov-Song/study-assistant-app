import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import 'models/action_result.dart';

class CasService {
  final Dio _dio = DioClient.instance.dio;

  /// 分发用户输入，返回 ActionResult。
  /// 网络失败 / 超时时返回本地兜底，不抛出异常。
  Future<ActionResult> dispatch(String text, {String? sessionId}) async {
    try {
      final res = await _dio
          .post(
            '/api/cas/dispatch',
            data: {
              'text': text,
              if (sessionId != null) 'session_id': sessionId,
            },
          )
          .timeout(const Duration(seconds: 10));
      return ActionResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return ActionResult.localFallback(message: '请求超时，请稍后再试');
      }
      return ActionResult.localFallback();
    } catch (_) {
      return ActionResult.localFallback();
    }
  }

  /// 获取所有已注册 Action 摘要列表。
  Future<List<ActionSummary>> listActions() async {
    try {
      final res = await _dio.get('/api/cas/actions');
      final list = (res.data['actions'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ActionSummary.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
