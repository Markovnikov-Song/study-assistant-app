import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tools/mindmap/export_service.dart';
import '../providers/mindmap_providers.dart';

// ── Export handlers ───────────────────────────────────────────────────────────

/// Exports the current mindmap as a Markdown file and triggers the system
/// share sheet.
///
/// Requirements: 11.1, 11.2
Future<void> handleExportMarkdown(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
  String mindmapId,
) async {
  final state = ref.read(nodeTreeProvider((subjectId, mindmapId)));
  final markdown = ExportService.toMarkdown(state.roots);
  final filename = 'mindmap_${DateTime.now().millisecondsSinceEpoch}.md';
  await ExportService.shareMarkdown(markdown, filename);
}

/// Captures the canvas as a PNG and saves it to the application documents
/// directory.
///
/// Requirements: 11.3
Future<void> handleExportPng(
  BuildContext context,
  GlobalKey repaintKey,
  WidgetRef ref,
  int subjectId,
  String mindmapId,
) async {
  try {
    final bytes = await ExportService.toPng(repaintKey);
    final filename = 'mindmap_${DateTime.now().millisecondsSinceEpoch}.png';
    await ExportService.savePng(bytes, filename);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导图已保存到文件')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }
}
