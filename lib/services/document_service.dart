import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/document.dart';

class DocumentService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<StudyDocument>> getDocuments(int subjectId) async {
    try {
      final res = await _dio.get(ApiConstants.documents, queryParameters: {'subject_id': subjectId});
      return (res.data as List).map((e) => StudyDocument.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<int> uploadDocument({
    required List<int> fileBytes,
    required String filename,
    required int subjectId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: filename),
        'subject_id': subjectId,
      });
      final res = await _dio.post(ApiConstants.documents, data: formData);
      return (res.data as Map<String, dynamic>)['doc_id'] as int;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteDocument(int docId, int subjectId) async {
    try {
      await _dio.delete(
        '${ApiConstants.documents}/$docId',
        queryParameters: {'subject_id': subjectId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
