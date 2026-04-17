import 'package:flutter/material.dart';

/// How imported content should be applied to the current mindmap.
enum ImportMode {
  /// Replace the entire current tree with the imported tree.
  replace,

  /// Append the imported tree as additional root nodes, preserving existing nodes.
  merge,
}

/// Shows a dialog asking the user whether to replace or merge the current
/// mindmap with newly imported / AI-generated content.
///
/// Returns [ImportMode.replace], [ImportMode.merge], or `null` if cancelled.
///
/// Requirements: 6.1–6.3, 7.4, 9.4
Future<ImportMode?> showImportModeDialog(BuildContext context) {
  return showDialog<ImportMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('导入方式'),
      content: const Text('如何处理导入的内容？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, ImportMode.merge),
          child: const Text('合并到当前导图'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ImportMode.replace),
          child: const Text('替换当前导图'),
        ),
      ],
    ),
  );
}
