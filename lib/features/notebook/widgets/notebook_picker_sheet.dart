import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/chat_message.dart';
import '../../../models/notebook.dart';
import '../../../providers/multi_select_provider.dart';
import '../../../providers/notebook_provider.dart';
import '../../../providers/subject_provider.dart';
import '../../../services/notebook_service.dart';

/// 笔记本选择面板（底部弹出）
/// 需求：4.4, 5.1, 5.2, 5.3, 5.4, 8.2
class NotebookPickerSheet extends ConsumerStatefulWidget {
  const NotebookPickerSheet({
    super.key,
    required this.selectedMessageIds,
    required this.messages,
    this.subjectId,
  });

  /// 当前多选模式下选中的消息 ID 集合
  final Set<int> selectedMessageIds;

  /// 聊天页所有消息列表，用于查找选中消息的内容
  final List<ChatMessage> messages;

  /// 当前学科 ID（用于默认选中学科下拉框）
  final int? subjectId;

  @override
  ConsumerState<NotebookPickerSheet> createState() =>
      _NotebookPickerSheetState();
}

class _NotebookPickerSheetState extends ConsumerState<NotebookPickerSheet> {
  Notebook? _selectedNotebook;
  int? _selectedSubjectId; // null 表示"通用"
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId;
  }

  @override
  Widget build(BuildContext context) {
    final notebooksAsync = ref.watch(notebookListProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '选择笔记本',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),

          // 笔记本列表
          notebooksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('加载失败：$e',
                  style: const TextStyle(color: Colors.red)),
            ),
            data: (notebooks) {
              final active =
                  notebooks.where((n) => !n.isArchived).toList();
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: active.length,
                  itemBuilder: (context, index) {
                    final notebook = active[index];
                    final isSelected = _selectedNotebook?.id == notebook.id;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<int>(
                          value: notebook.id,
                          groupValue: _selectedNotebook?.id,
                          title: Text(notebook.name),
                          onChanged: (_) {
                            setState(() {
                              _selectedNotebook = notebook;
                            });
                          },
                        ),
                        // 选中后展示学科选择下拉框
                        if (isSelected)
                          subjectsAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (subjects) {
                              final activeSubjects = subjects
                                  .where((s) => !s.isArchived)
                                  .toList();
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    32, 0, 16, 8),
                                child: Row(
                                  children: [
                                    const Text('学科：'),
                                    const SizedBox(width: 8),
                                    DropdownButton<int?>(
                                      value: _selectedSubjectId,
                                      isDense: true,
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('通用'),
                                        ),
                                        ...activeSubjects.map(
                                          (s) => DropdownMenuItem<int?>(
                                            value: s.id,
                                            child: Text(s.name),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedSubjectId = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),

          const Divider(height: 1),

          // 确认收藏按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onConfirm,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认收藏'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onConfirm() async {
    if (_selectedNotebook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个笔记本')),
      );
      return;
    }

    // 从 messages 中找到选中的消息
    final selectedMessages = widget.messages
        .where((m) => widget.selectedMessageIds.contains(m.id))
        .toList();

    if (selectedMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一条消息')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 构建批量创建笔记的请求体
    final notesPayload = selectedMessages.map((msg) {
      return {
        'notebook_id': _selectedNotebook!.id,
        'subject_id': _selectedSubjectId,
        'source_session_id': null, // 聊天页不传 session ID
        'source_message_id': msg.id,
        'role': msg.isUser ? 'user' : 'assistant',
        'original_content': msg.content,
        'sources': msg.sources
            ?.map((s) => {
                  'filename': s.filename,
                  'chunk_index': s.chunkIndex,
                  'content': s.content,
                  'score': s.score,
                })
            .toList(),
      };
    }).toList();

    try {
      await NotebookService().createNotes(notesPayload);

      if (!mounted) return;

      final notebookName = _selectedNotebook!.name;
      final count = selectedMessages.length;

      // 成功：退出多选模式
      ref.read(multiSelectProvider.notifier).cancel();
      // 刷新笔记本内容
      ref.invalidate(notebookNotesProvider(_selectedNotebook!.id));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已收藏 $count 条笔记到《$notebookName》')),
      );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收藏失败，请重试')),
      );

      Navigator.of(context).pop();
    }
  }
}
