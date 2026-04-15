import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../models/mindmap_library.dart';
import '../../../services/library_service.dart';

/// LectureExporter — exports lecture content to Markdown, PDF, or Word.
///
/// Feature: mindmap-library
class LectureExporter {
  // ── Markdown export ───────────────────────────────────────────────────────

  /// Export [blocks] to a Markdown string and trigger file save.
  static Future<void> exportToMarkdown(List<LectureBlock> blocks) async {
    final md = _blocksToMarkdown(blocks);
    final bytes = Uint8List.fromList(md.codeUnits);
    try {
      await FileSaver.instance.saveFile(
        name: 'lecture',
        bytes: bytes,
        ext: 'md',
        mimeType: MimeType.text,
      );
    } catch (e) {
      debugPrint('Markdown export failed: $e');
      rethrow;
    }
  }

  /// Convert blocks to Markdown string.
  static String _blocksToMarkdown(List<LectureBlock> blocks) {
    final buf = StringBuffer();
    for (final block in blocks) {
      switch (block.type) {
        case 'heading':
          final level = block.level ?? 1;
          buf.writeln('${'#' * level} ${block.text}');
        case 'paragraph':
          buf.writeln(_applySpans(block.text, block.spans));
        case 'code':
          final lang = block.language ?? '';
          buf.writeln('```$lang');
          buf.writeln(block.text);
          buf.writeln('```');
        case 'list':
          buf.writeln('- ${block.text}');
        case 'quote':
          buf.writeln('> ${block.text}');
        default:
          buf.writeln(block.text);
      }
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  /// Apply inline spans (bold/italic/code) to text for Markdown output.
  static String _applySpans(String text, List<LectureSpan> spans) {
    if (spans.isEmpty) return text;
    final result = StringBuffer();
    int cursor = 0;
    final sorted = List<LectureSpan>.from(spans)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final span in sorted) {
      if (span.start > cursor) {
        result.write(text.substring(cursor, span.start));
      }
      final spanText = text.substring(
        span.start.clamp(0, text.length),
        span.end.clamp(0, text.length),
      );
      String wrapped = spanText;
      if (span.code) wrapped = '`$wrapped`';
      if (span.bold) wrapped = '**$wrapped**';
      if (span.italic) wrapped = '_${wrapped}_';
      result.write(wrapped);
      cursor = span.end;
    }
    if (cursor < text.length) result.write(text.substring(cursor));
    return result.toString();
  }

  // ── PDF export ────────────────────────────────────────────────────────────

  /// Export [blocks] to a PDF file and trigger file save.
  static Future<void> exportToPdf(List<LectureBlock> blocks) async {
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (ctx) => blocks.map((b) => _blockToPdfWidget(b)).toList(),
        ),
      );
      final bytes = await doc.save();
      await FileSaver.instance.saveFile(
        name: 'lecture',
        bytes: Uint8List.fromList(bytes),
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (e) {
      debugPrint('PDF export failed: $e');
      rethrow;
    }
  }

  static pw.Widget _blockToPdfWidget(LectureBlock block) {
    switch (block.type) {
      case 'heading':
        final level = block.level ?? 1;
        final fontSize = level == 1 ? 20.0 : level == 2 ? 16.0 : 14.0;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
          child: pw.Text(
            block.text,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
      case 'code':
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              block.text,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        );
      case 'list':
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16, top: 2, bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: const pw.TextStyle(fontSize: 13)),
              pw.Expanded(
                child: pw.Text(block.text, style: const pw.TextStyle(fontSize: 13)),
              ),
            ],
          ),
        );
      case 'quote':
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Container(
            padding: const pw.EdgeInsets.only(left: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey400, width: 3),
              ),
            ),
            child: pw.Text(
              block.text,
              style: pw.TextStyle(
                fontSize: 13,
                color: PdfColors.grey700,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        );
      default:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Text(block.text, style: const pw.TextStyle(fontSize: 13)),
        );
    }
  }

  // ── Word export (via backend) ─────────────────────────────────────────────

  /// Call backend to generate .docx and trigger file save.
  static Future<void> exportToDocx({
    required BuildContext context,
    required int lectureId,
    required LibraryService service,
  }) async {
    try {
      final bytes = await service.exportLecture(lectureId, format: 'docx');
      await FileSaver.instance.saveFile(
        name: 'lecture',
        bytes: Uint8List.fromList(bytes),
        ext: 'docx',
        mimeType: MimeType.microsoftWord,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败：$e'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => exportToDocx(
                context: context,
                lectureId: lectureId,
                service: service,
              ),
            ),
          ),
        );
      }
    }
  }
}
