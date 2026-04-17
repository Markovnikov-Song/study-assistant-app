import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import '../../../models/mindmap_library.dart';
import '../../../services/library_service.dart';

class LectureExporter {
  /// 生成文件名：{节点名}_{日期}，去掉非法字符
  static String _filename(String nodeText) {
    final date = DateTime.now();
    final d =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    // 去掉文件名里不合法的字符
    final safe = nodeText.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '${safe}_$d';
  }

  // ── Markdown ──────────────────────────────────────────────────────────────

  static Future<void> exportToMarkdown(
    List<LectureBlock> blocks, {
    String nodeText = '讲义',
  }) async {
    final md = _blocksToMarkdown(blocks);
    final bytes = Uint8List.fromList(utf8.encode(md));
    await FileSaver.instance.saveFile(
      name: _filename(nodeText),
      bytes: bytes,
      ext: 'md',
      mimeType: MimeType.text,
    );
  }

  static String _blocksToMarkdown(List<LectureBlock> blocks) {
    final buf = StringBuffer();
    for (final block in blocks) {
      switch (block.type) {
        case 'heading':
          buf.writeln('${'#' * (block.level ?? 1)} ${block.text}');
        case 'paragraph':
          buf.writeln(_applySpans(block.text, block.spans));
        case 'code':
          buf.writeln('```${block.language ?? ''}');
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

  static String _applySpans(String text, List<LectureSpan> spans) {
    if (spans.isEmpty) return text;
    final result = StringBuffer();
    int cursor = 0;
    final sorted = List<LectureSpan>.from(spans)
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final span in sorted) {
      if (span.start > cursor) result.write(text.substring(cursor, span.start));
      final inner = text.substring(
        span.start.clamp(0, text.length),
        span.end.clamp(0, text.length),
      );
      String w = inner;
      if (span.code) w = '`$w`';
      if (span.bold) w = '**$w**';
      if (span.italic) w = '_${w}_';
      result.write(w);
      cursor = span.end;
    }
    if (cursor < text.length) result.write(text.substring(cursor));
    return result.toString();
  }

  // ── PDF (via backend) ─────────────────────────────────────────────────────

  static Future<void> exportToPdf(
    List<LectureBlock> blocks, {
    required BuildContext context,
    required int lectureId,
    required LibraryService service,
    String nodeText = '讲义',
  }) async {
    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('正在生成 PDF，请稍候…'),
        ]),
        duration: Duration(seconds: 60),
      ),
    );
    try {
      final bytes = await service.exportLecture(lectureId, format: 'pdf');
      if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await FileSaver.instance.saveFile(
        name: _filename(nodeText),
        bytes: Uint8List.fromList(bytes),
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF 导出失败：$e'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => exportToPdf(blocks,
                context: context,
                lectureId: lectureId,
                service: service,
                nodeText: nodeText),
          ),
        ));
      }
    }
  }

  // ── Word (via backend) ────────────────────────────────────────────────────

  static Future<void> exportToDocx({
    required BuildContext context,
    required int lectureId,
    required LibraryService service,
    String nodeText = '讲义',
  }) async {
    try {
      final bytes = await service.exportLecture(lectureId, format: 'docx');
      await FileSaver.instance.saveFile(
        name: _filename(nodeText),
        bytes: Uint8List.fromList(bytes),
        ext: 'docx',
        mimeType: MimeType.microsoftWord,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('导出失败：$e'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => exportToDocx(
                context: context,
                lectureId: lectureId,
                service: service,
                nodeText: nodeText),
          ),
        ));
      }
    }
  }
}
