import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/subject.dart';

class SubjectService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<Subject>> getSubjects({bool includeArchived = true}) async {
    try {
      final res = await _dio.get(ApiConstants.subjects, queryParameters: {'include_archived': includeArchived});
      return (res.data as List).map((e) => Subject.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Subject> createSubject(String name, {String? category, String? description}) async {
    try {
      final res = await _dio.post(ApiConstants.subjects, data: {
        'name': name,
        'category': ?category,
        'description': ?description,
      });
      return Subject.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Subject> updateSubject(int id, {required String name, String? category, String? description}) async {
    try {
      final res = await _dio.put('${ApiConstants.subjects}/$id', data: {
        'name': name,
        'category': category,
        'description': description,
      });
      return Subject.fromJson(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteSubject(int id) async {
    try {
      await _dio.delete('${ApiConstants.subjects}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> togglePin(int id) async {
    try {
      await _dio.post('${ApiConstants.subjects}/$id/pin');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> toggleArchive(int id) async {
    try {
      await _dio.post('${ApiConstants.subjects}/$id/archive');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
