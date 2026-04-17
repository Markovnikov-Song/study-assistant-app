import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/import_parser.dart';
import '../providers/mindmap_providers.dart';
import 'import_mode_dialog.dart';

// ── File import ───────────────────────────────────────────────────────────────

/// Opens the system file picker for `.xmind` / `.mm` files, parses the
/// selected file, and applies the result to the current mindmap tree.
///
/// Requirements: 7.1–7.6
Future<void> handleFileImport(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
  String mindmapId,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xmind', 'mm'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;

  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) return;

  final parseResult = ImportParser.parseFile(bytes, file.name);

  if (parseResult is ImportError) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_importErrorMessage(parseResult.type))),
      );
    }
    return;
  }

  final roots = (parseResult as ImportSuccess).roots;
  if (!context.mounted) return;

  final mode = await showImportModeDialog(context);
  if (mode == null || !context.mounted) return;

  final notifier =
      ref.read(nodeTreeProvider((subjectId, mindmapId)).notifier);
  if (mode == ImportMode.replace) {
    notifier.replaceTree(roots);
  } else {
    notifier.mergeTree(roots);
  }
}

String _importErrorMessage(ImportErrorType type) => switch (type) {
      ImportErrorType.unsupportedFormat =>
        '不支持该文件格式，请选择 .xmind 或 .mm 文件',
      ImportErrorType.parseFailure => '文件解析失败，请检查文件是否完整',
      ImportErrorType.noStructure => '未识别到有效的大纲结构',
    };

// ── Markdown paste ────────────────────────────────────────────────────────────

/// Shows a text-input dialog for pasting a Markdown outline, parses it, and
/// applies the result to the current mindmap tree.
///
/// Requirements: 8.1–8.4
Future<void> handleMarkdownPaste(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
  String mindmapId,
) async {
  final ctrl = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('粘贴 Markdown 大纲'),
      content: TextField(
        controller: ctrl,
        maxLines: 10,
        decoration: const InputDecoration(
          hintText: '粘贴 # 标题或 - 列表格式的大纲...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('导入'),
        ),
      ],
    ),
  );

  if (text == null || text.trim().isEmpty || !context.mounted) return;

  final parseResult = ImportParser.parseMarkdown(text);
  if (parseResult is ImportError) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未识别到有效的大纲结构，请使用 # 标题或 - 列表格式'),
        ),
      );
    }
    return;
  }

  final roots = (parseResult as ImportSuccess).roots;
  if (!context.mounted) return;

  final mode = await showImportModeDialog(context);
  if (mode == null || !context.mounted) return;

  final notifier =
      ref.read(nodeTreeProvider((subjectId, mindmapId)).notifier);
  if (mode == ImportMode.replace) {
    notifier.replaceTree(roots);
  } else {
    notifier.mergeTree(roots);
  }
}
