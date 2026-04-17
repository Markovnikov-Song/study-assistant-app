import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/export_service.dart';
import '../domain/import_parser.dart';
import '../providers/mindmap_providers.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/current_subject_provider.dart';
import 'import_mode_dialog.dart';

// ── AI optimize handler ───────────────────────────────────────────────────────

/// Sends the current mindmap tree to the AI service for optimisation.
///
/// The current tree is serialised to Markdown and passed as context to the
/// existing [ChatService.generateCustomMindMap] endpoint. The AI response is
/// then offered to the user as a merge or replace operation.
///
/// Requirements: 6.4, 6.5
Future<void> handleAiOptimize(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
  String mindmapId,
) async {
  final state = ref.read(nodeTreeProvider((subjectId, mindmapId)));
  final currentMarkdown = ExportService.toMarkdown(state.roots);

  if (currentMarkdown.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前导图为空，请先添加节点')),
    );
    return;
  }

  // Build a prompt that includes the current tree as context
  final prompt =
      '请优化并补充以下思维导图结构，保持原有层级关系，可以增加遗漏的知识点：\n\n$currentMarkdown';

  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final chatService = ref.read(chatServiceProvider);
    final subjectIdForAi = ref.read(currentSubjectProvider)?.id;

    final aiMarkdown = await chatService.generateCustomMindMap(
      prompt,
      subjectId: subjectIdForAi,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // close loading

    // Parse the AI response as a Markdown outline
    final parseResult = ImportParser.parseMarkdown(aiMarkdown);

    if (parseResult is ImportError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 返回内容无法解析为导图结构')),
      );
      return;
    }

    final roots = (parseResult as ImportSuccess).roots;
    final mode = await showImportModeDialog(context);
    if (mode == null || !context.mounted) return;

    final notifier =
        ref.read(nodeTreeProvider((subjectId, mindmapId)).notifier);
    if (mode == ImportMode.replace) {
      notifier.replaceTree(roots);
    } else {
      notifier.mergeTree(roots);
    }
  } catch (e) {
    if (context.mounted) {
      // Close loading dialog if still showing
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 优化失败：$e')),
      );
    }
  }
}
