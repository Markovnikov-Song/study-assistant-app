import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mindmap_providers.dart';

/// Horizontal toolbar for the mindmap editor.
///
/// Contains undo/redo, import (file / markdown / OCR), AI optimize, and export
/// buttons. Callbacks are provided by the parent page so this widget stays
/// stateless and testable.
///
/// Requirements: 5.4, 5.5, 7.1, 8.1, 9.1, 11.1
class MindmapToolbar extends ConsumerWidget {
  final int subjectId;
  final String mindmapId;

  /// Key wrapping the canvas [RepaintBoundary] — used for PNG export.
  final GlobalKey repaintKey;

  // ── Callbacks (implemented by the parent page) ────────────────────────────
  final VoidCallback? onImportFile;
  final VoidCallback? onPasteMarkdown;
  final VoidCallback? onOcrPhoto;
  final VoidCallback? onAiOptimize;
  final VoidCallback? onExport;

  const MindmapToolbar({
    super.key,
    required this.subjectId,
    required this.mindmapId,
    required this.repaintKey,
    this.onImportFile,
    this.onPasteMarkdown,
    this.onOcrPhoto,
    this.onAiOptimize,
    this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state so the widget rebuilds when undo/redo availability changes.
    ref.watch(nodeTreeProvider((subjectId, mindmapId)));
    final notifier =
        ref.read(nodeTreeProvider((subjectId, mindmapId)).notifier);

    final canUndo = notifier.canUndo;
    final canRedo = notifier.canRedo;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Undo ──────────────────────────────────────────────────────────
          Tooltip(
            message: '撤销',
            child: IconButton(
              icon: const Icon(Icons.undo),
              onPressed: canUndo ? () => notifier.undo() : null,
            ),
          ),

          // ── Redo ──────────────────────────────────────────────────────────
          Tooltip(
            message: '重做',
            child: IconButton(
              icon: const Icon(Icons.redo),
              onPressed: canRedo ? () => notifier.redo() : null,
            ),
          ),

          const _Divider(),

          // ── Import file ───────────────────────────────────────────────────
          Tooltip(
            message: '导入文件',
            child: IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: onImportFile,
            ),
          ),

          // ── Paste Markdown ────────────────────────────────────────────────
          Tooltip(
            message: '粘贴 Markdown 大纲',
            child: IconButton(
              icon: const Icon(Icons.content_paste),
              onPressed: onPasteMarkdown,
            ),
          ),

          // ── OCR photo ─────────────────────────────────────────────────────
          Tooltip(
            message: '拍照识别',
            child: IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: onOcrPhoto,
            ),
          ),

          const _Divider(),

          // ── AI optimize ───────────────────────────────────────────────────
          Tooltip(
            message: '发送给 AI 优化',
            child: IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: onAiOptimize,
            ),
          ),

          const _Divider(),

          // ── Export (popup menu) ───────────────────────────────────────────
          Tooltip(
            message: '导出',
            child: IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: onExport,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small vertical divider ────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: VerticalDivider(
        width: 16,
        thickness: 1,
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}
