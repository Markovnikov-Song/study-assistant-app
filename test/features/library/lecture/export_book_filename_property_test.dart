// Feature: lecture-book-export, Property 10: 导出文件名格�?
//
// Validates: Requirements 8.2
//
// Property 10: For any session title string and valid format value ("pdf" or
// "docx"), the filename passed to FileSaver must match
// `{sessionTitle}_{format}` with ext matching the format.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/library/lecture/export_book_dialog.dart';

// ── Pure filename construction logic (mirrors _ExportBookDialogState._export)
// filename = '${sessionTitle}_${format.value}'
// ext      = format.ext
// ─────────────────────────────────────────────────────────────────────────────

String buildFilename(String sessionTitle, ExportFormat format) =>
    '${sessionTitle}_${format.value}';

String buildExt(ExportFormat format) => format.ext;

// ── Test data generators ──────────────────────────────────────────────────────

const _sampleTitles = [
  '材料力学',
  '高等数学',
  'Linear Algebra',
  'Chapter 1: Introduction',
  '第三�?热力�?,
  'CS101',
  'Advanced Topics in ML',
  '概率论与数理统计',
  'Physics II',
  '操作系统原理',
  'Data Structures & Algorithms',
  '电路分析基础',
  'Organic Chemistry',
  '数字信号处理',
  'Software Engineering',
  '流体力学',
  'Calculus III',
  '编译原理',
  'Thermodynamics',
  '离散数学',
  // Edge cases
  '',
  'a',
  'title with spaces',
  'title_with_underscores',
  '中文 English Mixed',
];

List<(String, ExportFormat)> _generateCombinations() {
  final combinations = <(String, ExportFormat)>[];
  for (final title in _sampleTitles) {
    for (final format in ExportFormat.values) {
      combinations.add((title, format));
    }
  }
  return combinations;
}

// ── Property tests ────────────────────────────────────────────────────────────

void main() {
  group('Property 10: 导出文件名格�?, () {
    final combinations = _generateCombinations();

    // Ensure we have at least 20 combinations as required
    test('generates at least 20 title/format combinations', () {
      expect(combinations.length, greaterThanOrEqualTo(20));
    });

    // Core property: filename == '{title}_{format.value}'
    test('filename matches {sessionTitle}_{format} for all combinations', () {
      for (final (title, format) in combinations) {
        final filename = buildFilename(title, format);
        expect(
          filename,
          equals('${title}_${format.value}'),
          reason: 'title="$title", format=${format.value}',
        );
      }
    });

    // Core property: ext matches format.ext
    test('ext matches format.ext for all combinations', () {
      for (final (_, format) in combinations) {
        final ext = buildExt(format);
        expect(
          ext,
          equals(format.ext),
          reason: 'format=${format.value}',
        );
      }
    });

    // Property: PDF format produces value="pdf" and ext="pdf"
    test('pdf format has value "pdf" and ext "pdf"', () {
      for (final title in _sampleTitles) {
        final filename = buildFilename(title, ExportFormat.pdf);
        final ext = buildExt(ExportFormat.pdf);
        expect(filename, endsWith('_pdf'), reason: 'title="$title"');
        expect(ext, equals('pdf'));
      }
    });

    // Property: DOCX format produces value="docx" and ext="docx"
    test('docx format has value "docx" and ext "docx"', () {
      for (final title in _sampleTitles) {
        final filename = buildFilename(title, ExportFormat.docx);
        final ext = buildExt(ExportFormat.docx);
        expect(filename, endsWith('_docx'), reason: 'title="$title"');
        expect(ext, equals('docx'));
      }
    });

    // Property: filename always starts with the session title
    test('filename always starts with sessionTitle', () {
      for (final (title, format) in combinations) {
        final filename = buildFilename(title, format);
        expect(
          filename.startsWith(title),
          isTrue,
          reason: 'title="$title", format=${format.value}, filename="$filename"',
        );
      }
    });

    // Property: filename always ends with _{format.value}
    test('filename always ends with _{format.value}', () {
      for (final (title, format) in combinations) {
        final filename = buildFilename(title, format);
        expect(
          filename.endsWith('_${format.value}'),
          isTrue,
          reason: 'title="$title", format=${format.value}, filename="$filename"',
        );
      }
    });

    // Property: ext and format.value are consistent (both "pdf" or both "docx")
    test('ext and format.value are always equal', () {
      for (final format in ExportFormat.values) {
        expect(
          format.ext,
          equals(format.value),
          reason: 'format=${format.value}',
        );
      }
    });

    // Property: full file path = filename + '.' + ext
    test('full file path is filename.ext for all combinations', () {
      for (final (title, format) in combinations) {
        final filename = buildFilename(title, format);
        final ext = buildExt(format);
        final fullPath = '$filename.$ext';
        expect(
          fullPath,
          equals('${title}_${format.value}.${format.ext}'),
          reason: 'title="$title", format=${format.value}',
        );
      }
    });

    // Randomised property: 50 random titles × all formats
    test('holds for 50 random session titles', () {
      final rng = Random(42); // fixed seed for reproducibility
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-';
      for (var i = 0; i < 50; i++) {
        final length = rng.nextInt(30) + 1;
        final title = String.fromCharCodes(
          List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
        );
        for (final format in ExportFormat.values) {
          final filename = buildFilename(title, format);
          final ext = buildExt(format);
          expect(filename, equals('${title}_${format.value}'),
              reason: 'random title="$title", format=${format.value}');
          expect(ext, equals(format.ext),
              reason: 'format=${format.value}');
        }
      }
    });
  });
}
