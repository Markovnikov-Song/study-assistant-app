import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/document.dart';

class ExamService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<PastExamFile>> getPastExams(int subjectId) async {
    try {
      final res = await _dio.get(ApiConstants.pastExams, queryParameters: {'subject_id': subjectId});
      return (res.data as List).map((e) => PastExamFile.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<Map<String, dynamic>>> getQuestions(int examId) async {
    try {
      final res = await _dio.get('${ApiConstants.pastExams}/$examId/questions');
      return (res.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<int> uploadExam({
    required List<int> fileBytes,
    required String filename,
    required int subjectId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: filename),
        'subject_id': subjectId,
      });
      final res = await _dio.post(ApiConstants.pastExams, data: formData);
      return (res.data as Map<String, dynamic>)['file_id'] as int;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteExam(int examId, int subjectId) async {
    try {
      await _dio.delete(
        '${ApiConstants.pastExams}/$examId',
        queryParameters: {'subject_id': subjectId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<String> generatePredictedPaper(int subjectId) async {
    try {
      final res = await _dio.post(ApiConstants.examPredicted, data: {'subject_id': subjectId});
      return res.data['result'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<String> generateCustomQuiz({
    required int subjectId,
    required List<String> questionTypes,
    required Map<String, int> typeCounts,
    required Map<String, int> typeScores,
    required String difficulty,
    String? topic,
  }) async {
    try {
      final res = await _dio.post(ApiConstants.examCustom, data: {
        'subject_id': subjectId,
        'question_types': questionTypes,
        'type_counts': typeCounts,
        'type_scores': typeScores,
        'difficulty': difficulty,
        'topic': ?topic,
      });
      return res.data['result'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
