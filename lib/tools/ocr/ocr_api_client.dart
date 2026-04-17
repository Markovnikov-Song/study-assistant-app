import 'dart:typed_data';

import 'package:dio/dio.dart';

// ── Exceptions ────────────────────────────────────────────────────────────────

/// Base exception for OCR-related errors.
class OcrException implements Exception {
  final String message;
  const OcrException(this.message);
  @override
  String toString() => 'OcrException: $message';
}

/// Thrown when the OCR request exceeds the 30-second timeout.
class OcrTimeoutException extends OcrException {
  const OcrTimeoutException() : super('识别超时，请重试或手动输入');
}

// ── OcrApiClient ──────────────────────────────────────────────────────────────

/// Calls the backend OCR API to recognise text in an image.
///
/// Requirements: 9.2, 9.7
class OcrApiClient {
  final Dio _dio;
  static const Duration _timeout = Duration(seconds: 30);

  OcrApiClient(this._dio);

  /// Upload [imageBytes] to `POST /api/ocr/recognize` as multipart form data.
  ///
  /// The field name is `"image"` and the filename defaults to [filename].
  ///
  /// Returns the decoded JSON body:
  /// ```json
  /// { "lines": [{ "text": "...", "confidence": 0.9, "indent_level": 0 }] }
  /// ```
  ///
  /// Throws [OcrTimeoutException] on send/receive/connection timeout.
  /// Throws [OcrException] for any other Dio error.
  Future<Map<String, dynamic>> recognize(
    Uint8List imageBytes,
    String filename,
  ) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(imageBytes, filename: filename),
      });
      final response = await _dio.post(
        '/api/ocr/recognize',
        data: formData,
        options: Options(sendTimeout: _timeout, receiveTimeout: _timeout),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        throw const OcrTimeoutException();
      }
      throw const OcrException('图片识别失败，请确保图片清晰且包含文字内容');
    }
  }
}
