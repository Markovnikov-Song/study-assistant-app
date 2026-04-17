import 'dart:async';
import 'package:dio/dio.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../core/storage/storage_service.dart';
import '../models/mindmap_library.dart';

import 'package:study_assistant_app/tools/network/sse_client_stub.dart'
    if (dart.library.html) 'package:study_assistant_app/tools/network/sse_client_web.dart'
    if (dart.library.io) 'package:study_assistant_app/tools/network/sse_client_native.dart';

class LibraryService {
  final Dio _dio = DioClient.instance.dio;

  static const _base = '/api/library';

  // ── Subjects ──────────────────────────────────────────────────────────────
  Future<List<SubjectWithProgress>> getSubjects() async {
    try {
      final res = await _dio.get('$_base/subjects');
      return (res.data as List)
          .map((e) => SubjectWithProgress.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<List<MindMapSession>> getSessions(int subjectId) async {
    try {
      final res = await _dio.get('$_base/subjects/$subjectId/sessions');
      return (res.data as List)
          .map((e) => MindMapSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> renameSession(int sessionId, String title) async {
    try {
      await _dio.patch('$_base/sessions/$sessionId/title', data: {'title': title});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      await _dio.delete('$_base/sessions/$sessionId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updateSessionMeta(int sessionId, {bool? isPinned, int? sortOrder}) async {
    try {
      await _dio.patch('$_base/sessions/$sessionId/meta', data: {
        if (isPinned != null) 'is_pinned': isPinned,
        if (sortOrder != null) 'sort_order': sortOrder,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Nodes ─────────────────────────────────────────────────────────────────

  Future<List<TreeNode>> getNodes(int sessionId) async {
    try {
      final res = await _dio.get('$_base/sessions/$sessionId/nodes');
      final flat = (res.data['nodes'] as List)
          .cast<Map<String, dynamic>>();
      return TreeNode.buildTree(flat);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updateContent(int sessionId, String markdown) async {
    try {
      await _dio.patch('$_base/sessions/$sessionId/content', data: {'content': markdown});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, bool>> getNodeStates(int sessionId) async {
    try {
      final res = await _dio.get('$_base/sessions/$sessionId/node-states');
      return (res.data as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as bool),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> updateNodeStates(int sessionId, Map<String, bool> states) async {
    try {
      final items = states.entries
          .map((e) => {'node_id': e.key, 'is_lit': e.value})
          .toList();
      await _dio.post(
        '$_base/sessions/$sessionId/node-states',
        data: {'states': items},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Lectures ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getLecture(int sessionId, String nodeId) async {
    try {
      final res = await _dio.get(
        '$_base/lectures/$sessionId',
        queryParameters: {'node_id': nodeId},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<int> generateLecture({
    required int sessionId,
    required String nodeId,
    required Map<String, dynamic> content,
    Map<String, dynamic>? resourceScope,
  }) async {
    try {
      final data = <String, dynamic>{
        'session_id': sessionId,
        'node_id': nodeId,
        'content': content,
      };
      if (resourceScope != null) {
        data['resource_scope'] = resourceScope;
      }
      final res = await _dio.post('$_base/lectures', data: data);
      return res.data['id'] as int;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 流式生成讲义，返回 Stream of String（SSE token 流）
  Stream<String> generateLectureStream({
    required int sessionId,
    required String nodeId,
  }) {
    final url = '${_dio.options.baseUrl}$_base/lectures/stream';
    final body = <String, dynamic>{
      'session_id': sessionId,
      'node_id': nodeId,
      'content': <String, dynamic>{},
    };
    // 复用 SSE 客户端
    return _streamPost(url, body);
  }

  Stream<String> _streamPost(String url, Map<String, dynamic> body) {
    // 通过 StorageService 获取 token 后发起 SSE 请求
    final ctrl = StreamController<String>();
    _doStream(url, body, ctrl);
    return ctrl.stream;
  }

  Future<void> _doStream(String url, Map<String, dynamic> body, StreamController<String> ctrl) async {
    try {
      final token = await StorageService.instance.getToken();
      final stream = ssePost(url, body, token);
      await for (final event in stream) {
        ctrl.add(event);
      }
    } catch (e, st) {
      ctrl.addError(e, st);
    } finally {
      ctrl.close();
    }
  }

  Future<void> patchLecture(int lectureId, Map<String, dynamic> content) async {
    try {
      await _dio.patch('$_base/lectures/$lectureId', data: {'content': content});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteLecture(int sessionId, String nodeId) async {
    try {
      await _dio.delete(
        '$_base/lectures/$sessionId',
        queryParameters: {'node_id': nodeId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<int>> exportLecture(int lectureId, {String format = 'docx'}) async {
    try {
      final res = await _dio.post(
        '$_base/lectures/$lectureId/export',
        queryParameters: {'format': format},
        options: Options(responseType: ResponseType.bytes),
      );
      return (res.data as List).cast<int>();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
