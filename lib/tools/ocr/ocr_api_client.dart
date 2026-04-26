import 'dart:convert';
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

  /// Upload [imageBytes] to `POST /api/ocr/image` as JSON with base64 encoding.
  ///
  /// Request body: `{"image": "<base64>"}` — matches backend `OcrIn(image: str)`.
  /// Response body: `{"text": "..."}` — matches backend `OcrOut(text: str)`.
  ///
  /// Throws [OcrTimeoutException] on send/receive/connection timeout.
  /// Throws [OcrException] for any other Dio error.
  Future<Map<String, dynamic>> recognize(
    Uint8List imageBytes,
    String filename,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await _dio.post(
        '/api/ocr/image',
        data: {'image': base64Image},
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
