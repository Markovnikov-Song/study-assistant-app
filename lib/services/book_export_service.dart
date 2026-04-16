import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

class BookExportException implements Exception {
  final String message;
  final int? statusCode;

  const BookExportException({required this.message, this.statusCode});

  @override
  String toString() => 'BookExportException($statusCode): $message';
}

class BookExportService {
  static const _base = '/api/library';

  final Dio? _dio;

  /// [dio] is optional; defaults to [DioClient.instance.dio] when null.
  BookExportService({Dio? dio}) : _dio = dio;

  Future<Uint8List> exportBook({
    required int sessionId,
    required List<String> nodeIds,
    required String format,
    bool includeToc = true,
  }) async {
    final dio = _dio ?? DioClient.instance.dio;

    try {
      final res = await dio.post<List<int>>(
        '$_base/sessions/$sessionId/export-book',
        data: {
          'node_ids': nodeIds,
          'format': format,
          'include_toc': includeToc,
        },
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      return Uint8List.fromList(res.data!);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout) {
        throw const BookExportException(message: '导出超时，请减少选择的节点数量后重试');
      }
      if (e.type == DioExceptionType.badResponse) {
        final code = e.response?.statusCode;
        final detail = e.response?.data is Map
            ? (e.response!.data as Map)['detail']?.toString()
            : null;
        throw BookExportException(
          message: detail ?? '导出失败',
          statusCode: code,
        );
      }
      throw BookExportException(message: e.message ?? '导出失败');
    }
  }
}
