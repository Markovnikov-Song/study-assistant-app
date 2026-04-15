import 'package:flutter_quill/quill_delta.dart';
import '../../../models/mindmap_library.dart';

/// BlockConverter — converts between backend JSONB blocks and Quill Delta.
///
/// Feature: mindmap-library
/// Supports: heading (H1-H3), paragraph (bold/italic/code spans),
///           code block, list (ordered/unordered), quote.
class BlockConverter {
  // ── blocks → Quill Delta ──────────────────────────────────────────────────

  /// Convert a list of [LectureBlock] to a Quill [Delta].
  static Delta blocksToQuillDelta(List<LectureBlock> blocks) {
    final ops = <Map<String, dynamic>>[];

    for (final block in blocks) {
      switch (block.type) {
        case 'heading':
          _addHeading(ops, block);
        case 'paragraph':
          _addParagraph(ops, block);
        case 'code':
          _addCode(ops, block);
        case 'list':
          _addList(ops, block);
        case 'quote':
          _addQuote(ops, block);
        default:
          // Fallback: treat as paragraph
          ops.add({'insert': block.text});
          ops.add({'insert': '\n'});
      }
    }

    // Quill requires at least one trailing newline
    if (ops.isEmpty || ops.last['insert'] != '\n') {
      ops.add({'insert': '\n'});
    }

    return Delta.fromJson(ops);
  }

  static void _addHeading(List<Map<String, dynamic>> ops, LectureBlock block) {
    final level = block.level ?? 1;
    ops.add({'insert': block.text});
    ops.add({
      'insert': '\n',
      'attributes': {'header': level},
    });
  }

  static void _addParagraph(List<Map<String, dynamic>> ops, LectureBlock block) {
    // 如果 spans 为空但 text 含 inline markdown，自动解析
    final spans = block.spans.isNotEmpty
        ? block.spans
        : _parseInlineMarkdown(block.text);
    final text = block.spans.isNotEmpty
        ? block.text
        : _stripInlineMarkdown(block.text);

    if (spans.isEmpty) {
      ops.add({'insert': text});
    } else {
      int cursor = 0;
      final sortedSpans = List<LectureSpan>.from(spans)
        ..sort((a, b) => a.start.compareTo(b.start));

      for (final span in sortedSpans) {
        if (span.start > cursor) {
          ops.add({'insert': text.substring(cursor, span.start)});
        }
        final spanText = text.substring(
          span.start.clamp(0, text.length),
          span.end.clamp(0, text.length),
        );
        final attrs = <String, dynamic>{};
        if (span.bold) attrs['bold'] = true;
        if (span.italic) attrs['italic'] = true;
        if (span.code) attrs['code'] = true;
        ops.add({'insert': spanText, if (attrs.isNotEmpty) 'attributes': attrs});
        cursor = span.end;
      }
      if (cursor < text.length) {
        ops.add({'insert': text.substring(cursor)});
      }
    }
    ops.add({'insert': '\n'});
  }

  /// 从含 inline markdown 的文本中提取 spans（**bold**、*italic*、`code`）
  static List<LectureSpan> _parseInlineMarkdown(String raw) {
    final spans = <LectureSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    int offset = 0; // offset in the stripped output
    int cursor = 0; // cursor in raw

    for (final m in pattern.allMatches(raw)) {
      // plain text before this match
      offset += m.start - cursor;
      cursor = m.start;

      final full = m.group(0)!;
      if (full.startsWith('**')) {
        final inner = m.group(1)!;
        spans.add(LectureSpan(start: offset, end: offset + inner.length, bold: true));
        offset += inner.length;
      } else if (full.startsWith('*')) {
        final inner = m.group(2)!;
        spans.add(LectureSpan(start: offset, end: offset + inner.length, italic: true));
        offset += inner.length;
      } else {
        final inner = m.group(3)!;
        spans.add(LectureSpan(start: offset, end: offset + inner.length, code: true));
        offset += inner.length;
      }
      cursor = m.end;
    }
    return spans;
  }

  /// 去掉 inline markdown 符号，返回纯文本
  static String _stripInlineMarkdown(String raw) {
    return raw
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m.group(1)!);
  }

  static void _addCode(List<Map<String, dynamic>> ops, LectureBlock block) {
    ops.add({'insert': block.text});
    ops.add({
      'insert': '\n',
      'attributes': {'code-block': block.language ?? true},
    });
  }

  static void _addList(List<Map<String, dynamic>> ops, LectureBlock block) {
    // Detect ordered vs unordered from text prefix (best-effort)
    // Backend doesn't distinguish; default to bullet
    ops.add({'insert': block.text});
    ops.add({
      'insert': '\n',
      'attributes': {'list': 'bullet'},
    });
  }

  static void _addQuote(List<Map<String, dynamic>> ops, LectureBlock block) {
    ops.add({'insert': block.text});
    ops.add({
      'insert': '\n',
      'attributes': {'blockquote': true},
    });
  }

  // ── Quill Delta → blocks ──────────────────────────────────────────────────

  /// Convert a Quill [Delta] back to a list of [LectureBlock].
  /// Preserves [source] from existing blocks where possible (matched by text).
  static List<LectureBlock> quillDeltaToBlocks(
    Delta delta, {
    List<LectureBlock>? existingBlocks,
  }) {
    final blocks = <LectureBlock>[];
    final ops = delta.toJson() as List<dynamic>;

    // Build a text→source lookup from existing blocks
    final sourceMap = <String, String>{};
    if (existingBlocks != null) {
      for (final b in existingBlocks) {
        sourceMap[b.text] = b.source;
      }
    }

    String buffer = '';
    Map<String, dynamic> lineAttrs = {};
    final spans = <LectureSpan>[];

    void flushLine() {
      if (buffer.isEmpty) return;
      final source = sourceMap[buffer] ?? 'user';
      final block = _buildBlock(
        text: buffer,
        lineAttrs: lineAttrs,
        spans: List.from(spans),
        source: source,
      );
      if (block != null) blocks.add(block);
      buffer = '';
      lineAttrs = {};
      spans.clear();
    }

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = (op['attributes'] as Map?)?.cast<String, dynamic>() ?? {};

      final lines = insert.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final part = lines[i];
        if (i < lines.length - 1) {
          // This part ends with a newline
          if (part.isNotEmpty) {
            _appendToBuffer(part, attrs, buffer.length, spans);
            buffer += part;
          }
          // The newline carries line-level attributes
          final newlineAttrs = i == lines.length - 2 ? attrs : <String, dynamic>{};
          lineAttrs = newlineAttrs;
          flushLine();
        } else {
          // Last segment (no trailing newline yet)
          if (part.isNotEmpty) {
            _appendToBuffer(part, attrs, buffer.length, spans);
            buffer += part;
          }
        }
      }
    }
    flushLine();

    return blocks;
  }

  static void _appendToBuffer(
    String text,
    Map<String, dynamic> attrs,
    int offset,
    List<LectureSpan> spans,
  ) {
    final hasBold = attrs['bold'] == true;
    final hasItalic = attrs['italic'] == true;
    final hasCode = attrs['code'] == true;
    if (hasBold || hasItalic || hasCode) {
      spans.add(LectureSpan(
        start: offset,
        end: offset + text.length,
        bold: hasBold,
        italic: hasItalic,
        code: hasCode,
      ));
    }
  }

  static LectureBlock? _buildBlock({
    required String text,
    required Map<String, dynamic> lineAttrs,
    required List<LectureSpan> spans,
    required String source,
  }) {
    final id = 'block_${DateTime.now().microsecondsSinceEpoch}';

    if (lineAttrs.containsKey('header')) {
      final level = lineAttrs['header'] as int? ?? 1;
      return LectureBlock(id: id, type: 'heading', level: level, text: text, source: source);
    }
    if (lineAttrs['code-block'] != null) {
      final lang = lineAttrs['code-block'] is String ? lineAttrs['code-block'] as String : null;
      return LectureBlock(id: id, type: 'code', language: lang, text: text, source: source);
    }
    if (lineAttrs['list'] != null) {
      return LectureBlock(id: id, type: 'list', text: text, source: source);
    }
    if (lineAttrs['blockquote'] == true) {
      return LectureBlock(id: id, type: 'quote', text: text, source: source);
    }
    return LectureBlock(id: id, type: 'paragraph', text: text, source: source, spans: spans);
  }
}
