import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';

const _qaFallback = ['这道题的解题思路是什么？', '帮我总结这章的重点', '这个概念怎么理解？'];
const _solveFallback = ['求解：f(x) = x² + 2x + 1，求极值', '证明：勾股定理', '计算：∫x²dx'];

class HintService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<String>> getHints(int subjectId, String type) async {
    try {
      final res = await _dio.get(
        '${ApiConstants.hints}/$subjectId',
        queryParameters: {'type': type},
      );
      return (res.data['hints'] as List?)?.cast<String>() ?? [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> triggerRefresh(int subjectId, String type) async {
    try {
      await _dio.post(
        '${ApiConstants.hints}/$subjectId/refresh',
        queryParameters: {'type': type},
      );
    } catch (_) {
      // 静默忽略
    }
  }
}

final hintServiceProvider = Provider<HintService>((ref) => HintService());

// 只读缓存，不触发刷新，不 autoDispose（常驻避免闪烁）
// key = (subjectId, isQa)
final hintProvider = FutureProvider.family<List<String>, (int, bool)>((ref, key) async {
  final (subjectId, isQa) = key;
  final type = isQa ? 'qa' : 'solve';
  final hints = await ref.read(hintServiceProvider).getHints(subjectId, type);
  if (hints.isNotEmpty) return hints;
  return isQa ? _qaFallback : _solveFallback;
});

// 登录后调用一次，为所有学科触发后台刷新
Future<void> triggerHintRefreshOnLogin(WidgetRef ref, List<int> subjectIds) async {
  final service = ref.read(hintServiceProvider);
  for (final id in subjectIds) {
    service.triggerRefresh(id, 'qa');
    service.triggerRefresh(id, 'solve');
  }
}
