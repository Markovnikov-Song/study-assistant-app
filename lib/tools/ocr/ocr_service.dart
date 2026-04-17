import 'dart:typed_data';

import '../ocr/ocr_api_client.dart';
import '../mindmap/import_parser.dart';

// ── OcrResult ─────────────────────────────────────────────────────────────────

/// The result of an OCR recognition call.
class OcrResult {
  final List<OcrLine> lines;
  const OcrResult({required this.lines});
}

// ── OcrService ────────────────────────────────────────────────────────────────

/// Calls [OcrApiClient] and converts the raw JSON response into an [OcrResult].
///
/// Requirements: 9.2, 9.6
class OcrService {
  final OcrApiClient _client;

  OcrService(this._client);

  /// Recognise text in [imageBytes] and return an [OcrResult].
  ///
  /// Each [OcrLine] contains:
  /// - [OcrLine.text] — recognised text
  /// - [OcrLine.confidence] — confidence score (0.0–1.0)
  /// - [OcrLine.indentLevel] — inferred indent level (0-based)
  ///
  /// Propagates [OcrTimeoutException] and [OcrException] from [OcrApiClient].
  Future<OcrResult> recognize(
    Uint8List imageBytes, {
    String filename = 'image.jpg',
  }) async {
    final json = await _client.recognize(imageBytes, filename);
    final rawLines = json['lines'] as List<dynamic>;
    final lines = rawLines.map((e) {
      final map = e as Map<String, dynamic>;
      return OcrLine(
        text: map['text'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        indentLevel: (map['indent_level'] as num?)?.toInt() ?? 0,
      );
    }).toList();
    return OcrResult(lines: lines);
  }

  /// Returns `true` when [confidence] is below the highlight threshold (0.7).
  ///
  /// Property 18 — Validates: Requirements 9.6
  static bool shouldHighlight(double confidence) => confidence < 0.7;
}
