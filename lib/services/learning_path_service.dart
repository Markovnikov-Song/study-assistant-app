import 'package:dio/dio.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/mindmap_library.dart';

class LearningPathService {
  final Dio _dio = DioClient.instance.dio;

  static const _base = '/api/library';

  // ── Learning Paths ───────────────────────────────────────────────────────

  /// 获取学科的预设路径
  Future<LearningPath?> getLearningPath(int subjectId) async {
    try {
      final res = await _dio.get('$_base/subjects/$subjectId/learning-path');
      if (res.data == null) return null;
      return LearningPath.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取会话中所有节点状态
  Future<Map<String, NodeState>> getNodeStates(int sessionId) async {
    try {
      final res = await _dio.get('$_base/sessions/$sessionId/node-mastery-states');
      return _parseNodeStates(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 解析节点状态
  Map<String, NodeState> _parseNodeStates(Map<String, dynamic> data) {
    final result = <String, NodeState>{};
    for (final entry in data.entries) {
      final stateStr = entry.value as String? ?? 'locked';
      result[entry.key] = _stringToNodeState(stateStr);
    }
    return result;
  }

  /// 字符串转 NodeState
  NodeState _stringToNodeState(String state) {
    switch (state) {
      case 'locked':
        return NodeState.locked;
      case 'unlocked':
        return NodeState.unlocked;
      case 'in_progress':
      case 'inProgress':
        return NodeState.inProgress;
      case 'mastered':
        return NodeState.mastered;
      default:
        return NodeState.locked;
    }
  }

  /// NodeState 转字符串（用于 API）
  String _nodeStateToString(NodeState state) {
    switch (state) {
      case NodeState.locked:
        return 'locked';
      case NodeState.unlocked:
        return 'unlocked';
      case NodeState.inProgress:
        return 'in_progress';
      case NodeState.mastered:
        return 'mastered';
    }
  }

  // ── Node Mastery ─────────────────────────────────────────────────────────

  /// 获取节点掌握度
  Future<Map<String, NodeMastery>> getNodeMasteries(int sessionId) async {
    try {
      final res = await _dio.get('$_base/sessions/$sessionId/node-masteries');
      final data = res.data as Map<String, dynamic>;
      return data.map(
        (key, value) => MapEntry(
          key,
          NodeMastery.fromJson(value as Map<String, dynamic>),
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 更新节点状态
  Future<void> updateNodeState(
    int sessionId,
    String nodeId,
    NodeState state,
  ) async {
    try {
      await _dio.patch(
        '$_base/sessions/$sessionId/node-mastery-states/$nodeId',
        data: {'state': _nodeStateToString(state)},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 更新节点掌握度
  Future<void> updateNodeMastery(
    int sessionId,
    String nodeId, {
    int? correctCount,
    int? wrongCount,
    int? lectureReadDuration,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (correctCount != null) data['correct_count'] = correctCount;
      if (wrongCount != null) data['wrong_count'] = wrongCount;
      if (lectureReadDuration != null) {
        data['lecture_read_duration'] = lectureReadDuration;
      }
      if (data.isEmpty) return;

      await _dio.patch(
        '$_base/sessions/$sessionId/node-masteries/$nodeId',
        data: data,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}