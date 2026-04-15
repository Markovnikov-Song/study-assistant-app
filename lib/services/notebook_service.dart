import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/notebook.dart';

class NotebookService {
  final Dio _dio = DioClient.instance.dio;

  // ── Notebook CRUD ──────────────────────────────────────────────────────────

  Future<List<Notebook>> getNotebooks() async {
    try {
      final res = await _dio.get(ApiConstants.notebooks);
      return (res.data as List).map((e) => Notebook.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Notebook> createNotebook(String name) async {
    try {
      final res = await _dio.post(ApiConstants.notebooks, data: {'name': name});
      return Notebook.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Notebook> updateNotebook(
    int id, {
    String? name,
    bool? isPinned,
    bool? isArchived,
    int? sortOrder,
  }) async {
    try {
      final res = await _dio.patch('${ApiConstants.notebooks}/$id', data: {
        'name': ?name,
        'is_pinned': ?isPinned,
        'is_archived': ?isArchived,
        'sort_order': ?sortOrder,
      });
      return Notebook.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteNotebook(int id) async {
    try {
      await _dio.delete('${ApiConstants.notebooks}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Notes ──────────────────────────────────────────────────────────────────

  /// 返回按 subject_id 分组的笔记，key 为 null 表示"通用"（无学科）
  Future<Map<int?, List<Note>>> getNotebookNotes(int notebookId) async {
    try {
      final res = await _dio.get('${ApiConstants.notebooks}/$notebookId/notes');
      final Map<int?, List<Note>> grouped = {};
      final sections = (res.data['sections'] as List);
      for (final section in sections) {
        final key = section['subject_id'] as int?;
        grouped[key] = (section['notes'] as List)
            .map((e) => Note.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return grouped;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Note>> createNotes(List<Map<String, dynamic>> notes) async {
    try {
      final res = await _dio.post(ApiConstants.notes, data: {'notes': notes});
      return (res.data as List).map((e) => Note.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Note> getNote(int noteId) async {
    try {
      final res = await _dio.get('${ApiConstants.notes}/$noteId');
      return Note.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Note> updateNote(
    int noteId, {
    String? title,
    String? originalContent,
  }) async {
    try {
      final res = await _dio.patch('${ApiConstants.notes}/$noteId', data: {
        'title': ?title,
        'original_content': ?originalContent,
      });
      return Note.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteNote(int noteId) async {
    try {
      await _dio.delete('${ApiConstants.notes}/$noteId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── AI 操作 ────────────────────────────────────────────────────────────────

  Future<({String title, List<String> outline})> generateTitle(
      int noteId) async {
    try {
      final res = await _dio
          .post('${ApiConstants.notes}/$noteId/generate-title');
      return (
        title: res.data['title'] as String,
        outline: (res.data['outline'] as List).map((e) => e as String).toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<int> importToRag(int noteId) async {
    try {
      final res =
          await _dio.post('${ApiConstants.notes}/$noteId/import-to-rag');
      return (res.data['doc_id'] as num).toInt();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<String> polishNote(int noteId) async {
    try {
      final res = await _dio.post('${ApiConstants.notes}/$noteId/polish');
      return res.data['polished_content'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
