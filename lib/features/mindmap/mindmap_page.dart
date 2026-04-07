import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/document_provider.dart';
import '../../widgets/subject_bar.dart';
import '../../widgets/no_subject_hint.dart';

class MindMapPage extends ConsumerStatefulWidget {
  const MindMapPage({super.key});
  @override
  ConsumerState<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends ConsumerState<MindMapPage> {
  int? _selectedDocId; // null = 全部资料
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(currentSubjectProvider);
    return Scaffold(
      appBar: const SubjectBar(),
      body: subject == null
          ? const NoSubjectHint()
          : _MindMapBody(
              subjectId: subject.id,
              selectedDocId: _selectedDocId,
              generating: _generating,
              onDocChanged: (id) => setState(() => _selectedDocId = id),
              onGenerate: _generate,
            ),
    );
  }

  Future<void> _generate() async {
    final sid = ref.read(currentSubjectProvider)?.id;
    if (sid == null || _generating) return;
    setState(() => _generating = true);
    await ref.read(chatProvider(sid).notifier).generateMindMap(docId: _selectedDocId);
    setState(() => _generating = false);
  }
}

class _MindMapBody extends ConsumerWidget {
  final int subjectId;
  final int? selectedDocId;
  final bool generating;
  final ValueChanged<int?> onDocChanged;
  final VoidCallback onGenerate;

  const _MindMapBody({required this.subjectId, required this.selectedDocId, required this.generating, required this.onDocChanged, required this.onGenerate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider(subjectId));
    final chatState = ref.watch(chatProvider(subjectId));

    final content = chatState.maybeWhen(
      data: (msgs) => msgs.isNotEmpty && !msgs.last.isUser ? msgs.last.content : null,
      orElse: () => null,
    );

    return Column(
      children: [
        // 资料范围选择
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: docsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (docs) {
              final completed = docs.where((d) => d.status.name == 'completed').toList();
              return DropdownButtonFormField<int?>(
                value: selectedDocId,
                decoration: const InputDecoration(labelText: '资料范围', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部资料')),
                  ...completed.map((d) => DropdownMenuItem(value: d.id, child: Text(d.filename, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: onDocChanged,
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // 导图内容区
        Expanded(
          child: content != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(content, style: const TextStyle(height: 1.8)),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      const Text('点击下方按钮生成思维导图', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
        ),

        // 底部操作栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(
            children: [
              if (content != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {/* TODO: 导出 */},
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('导出 MD'),
                  ),
                ),
              if (content != null) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: generating ? null : onGenerate,
                  icon: generating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(generating ? '生成中…' : (content != null ? '重新生成' : '生成思维导图')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
