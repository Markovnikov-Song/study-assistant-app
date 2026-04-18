import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/hint_provider.dart';
import '../../providers/multi_select_provider.dart';
import '../../widgets/message_search_delegate.dart';
import '../../widgets/session_history_sheet.dart';
import '../../widgets/subject_bar.dart';
import '../../widgets/no_subject_hint.dart';
import '../../widgets/markdown_latex_view.dart';
import '../../widgets/mcp_status_indicator.dart';
import '../notebook/widgets/notebook_picker_sheet.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _useHybrid = false;
  bool _sending = false;

  @override
  void dispose() { _inputCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  int? get _subjectId => ref.read(currentSubjectProvider)?.id;
  (int, String) get _key => (_subjectId!, 'qa');

  void _bindSendingCallback() {
    final sid = _subjectId;
    if (sid == null) return;
    ref.read(chatProvider(_key).notifier).onSendingChanged = (v) {
      if (mounted) setState(() => _sending = v);
    };
  }

  Future<void> _submit() async {
    final sid = _subjectId;
    if (sid == null) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _bindSendingCallback();
    await ref.read(chatProvider(_key).notifier).sendMessage(
      text,
      mode: SessionType.qa,
      useHybrid: _useHybrid,
    );
    _scrollToBottom();
  }

  void _cancelSending() {
    final sid = _subjectId;
    if (sid == null) return;
    ref.read(chatProvider(_key).notifier).cancelSending();
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    final sid = _subjectId;
    if (sid == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final b64 = base64Encode(await file.readAsBytes());
    if (!mounted) return;
    final text = await ref.read(chatProvider(_key).notifier).recognizeOcr(b64);
    if (text != null && text.isNotEmpty && mounted) setState(() => _inputCtrl.text = text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(currentSubjectProvider);
    final multiSelect = ref.watch(multiSelectProvider);
    final selectedCount = multiSelect.selectedMessageIds.length;
    final sending = _sending;

    // 学科切换时重置发送状态，避免旧学科的 sending 状态残留
    ref.listen(currentSubjectProvider, (prev, next) {
      if (prev?.id != next?.id && _sending) {
        setState(() => _sending = false);
      }
    });

    PreferredSizeWidget appBar;
    if (multiSelect.isActive) {
      appBar = AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => ref.read(multiSelectProvider.notifier).cancel(),
        ),
        title: Text('已选中 $selectedCount 条消息'),
        centerTitle: false,
      );
    } else {
      appBar = AppBar(
        title: const SubjectBarTitle(),
        centerTitle: false,
        actions: const [
          McpStatusIndicator(),
          SizedBox(width: 8),
        ],
      );
    }

    return Scaffold(
      appBar: appBar,
      body: subject == null
          ? const NoSubjectHint()
          : _ChatBody(
              subjectId: subject.id,
              useHybrid: _useHybrid,
              sending: sending,
              inputCtrl: _inputCtrl,
              scrollCtrl: _scrollCtrl,
              onHybridChanged: (v) => setState(() => _useHybrid = v),
              onSubmit: _submit,
              onCancel: _cancelSending,
              onCamera: () => _pickAndOcr(ImageSource.camera),
              onGallery: () => _pickAndOcr(ImageSource.gallery),
            ),
    );
  }
}

class _ChatBody extends ConsumerWidget {
  final int subjectId;
  final bool useHybrid, sending;
  final TextEditingController inputCtrl;
  final ScrollController scrollCtrl;
  final ValueChanged<bool> onHybridChanged;
  final VoidCallback onSubmit, onCancel, onCamera, onGallery;

  const _ChatBody({required this.subjectId, required this.useHybrid, required this.sending,
    required this.inputCtrl, required this.scrollCtrl, required this.onHybridChanged,
    required this.onSubmit, required this.onCancel, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (subjectId, 'qa');
    final chatState = ref.watch(chatProvider(key));
    final multiSelect = ref.watch(multiSelectProvider);
    return Column(
      children: [
        _SessionBar(subjectId: subjectId),
        Expanded(
          child: chatState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            data: (msgs) => msgs.isEmpty
                  ? SingleChildScrollView(child: _EmptyHints(
                    subjectId: subjectId,
                    onTap: (h) => inputCtrl.text = h,
                  ))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: msgs.length + (sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (sending && i == msgs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: _TypingIndicator(),
                        );
                      }
                      return _Bubble(
                        message: msgs[i],
                        onDelete: multiSelect.isActive
                            ? null
                            : () => ref.read(chatProvider(key).notifier).deleteMessage(i),
                      );
                    },
                  ),
          ),
        ),
        if (!multiSelect.isActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                Checkbox(value: useHybrid, onChanged: (v) => onHybridChanged(v ?? false), visualDensity: VisualDensity.compact),
                const Text('结合通用知识', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Tooltip(
                  message: '优先检索知识库，检索不到时自动用通用知识回答',
                  child: Icon(Icons.info_outline, size: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          _InputBar(controller: inputCtrl, sending: sending, placeholder: '输入问题…', onSubmit: onSubmit, onCancel: onCancel, onCamera: onCamera, onGallery: onGallery),
        ] else
          _MultiSelectBar(
            subjectId: subjectId,
            messages: chatState.maybeWhen(data: (msgs) => msgs, orElse: () => []),
          ),
      ],
    );
  }
}

class _SessionBar extends ConsumerWidget {
  final int subjectId;
  const _SessionBar({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (subjectId, 'qa');
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _showHistory(context, ref),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('历史记录', style: TextStyle(fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: '搜索聊天记录',
            onPressed: () => showSearch(context: context, delegate: MessageSearchDelegate(ref)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => ref.read(chatProvider(key).notifier).newSession(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建对话', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    showSessionHistorySheet(context, ref, subjectId: subjectId, initialType: 'qa');
  }
}

class _Bubble extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onDelete;
  const _Bubble({required this.message, this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final cs = Theme.of(context).colorScheme;
    final multiSelect = ref.watch(multiSelectProvider);
    final isSelected = multiSelect.selectedMessageIds.contains(message.id);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (!multiSelect.isActive) {
            ref.read(multiSelectProvider.notifier).activate(message.id);
          } else {
            // 多选模式下长按也切换选中
            ref.read(multiSelectProvider.notifier).toggle(message.id);
          }
        },
        onTap: () {
          if (multiSelect.isActive) {
            ref.read(multiSelectProvider.notifier).toggle(message.id);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
          decoration: BoxDecoration(
            color: isUser ? cs.primary : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isSelected
                ? Border.all(color: Colors.blue, width: 2)
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isUser
                      ? (multiSelect.isActive
                          ? Text(message.content, style: TextStyle(color: cs.onPrimary, height: 1.5))
                          : SelectableText(message.content, style: TextStyle(color: cs.onPrimary, height: 1.5)))
                      : MarkdownLatexView(data: message.content, textStyle: TextStyle(color: cs.onSurface), codeBackgroundColor: cs.surfaceContainerHighest),
                  if (!isUser && message.sources != null && message.sources!.isNotEmpty)
                    _SourcesWidget(sources: message.sources!),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.check_circle, color: Colors.blue, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }

}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16),
          ),
        ),
        child: SizedBox(
          width: 48,
          child: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(4),
            color: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

class _MultiSelectBar extends ConsumerWidget {
  final int subjectId;
  final List<ChatMessage> messages;
  const _MultiSelectBar({required this.subjectId, required this.messages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiSelect = ref.watch(multiSelectProvider);
    final selectedCount = multiSelect.selectedMessageIds.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => ref.read(multiSelectProvider.notifier).cancel(),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () {
                if (selectedCount == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请至少选择一条消息')),
                  );
                  return;
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => NotebookPickerSheet(
                    selectedMessageIds: multiSelect.selectedMessageIds,
                    messages: messages,
                    subjectId: subjectId,
                  ),
                );
              },
              child: Text('收藏到笔记本 ($selectedCount)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcesWidget extends StatelessWidget {
  final List<MessageSource> sources;
  const _SourcesWidget({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          dense: true,
          title: Row(children: [
            const Icon(Icons.menu_book_outlined, size: 13, color: Colors.grey),
            const SizedBox(width: 4),
            Text('参考来源（${sources.length}处）', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          children: sources.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${s.filename}  第${s.chunkIndex + 1}段', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 4),
                Text(s.content.length > 100 ? '${s.content.substring(0, 100)}…' : s.content, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

class _EmptyHints extends ConsumerWidget {
  final int subjectId;
  final ValueChanged<String> onTap;
  const _EmptyHints({required this.subjectId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hintsAsync = ref.watch(hintProvider((subjectId, true)));
    final hints = hintsAsync.valueOrNull ?? const ['这道题的解题思路是什么？', '帮我总结这章的重点', '这个概念怎么理解？'];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('试试这些问题', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...hints.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(onPressed: () => onTap(h), child: Text(h, textAlign: TextAlign.center)),
            )),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final String placeholder;
  final VoidCallback onSubmit, onCancel, onCamera, onGallery;
  const _InputBar({required this.controller, required this.sending, required this.placeholder, required this.onSubmit, required this.onCancel, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: sending ? null : onCamera, tooltip: '拍照识题'),
          IconButton(icon: const Icon(Icons.image_outlined), onPressed: sending ? null : onGallery, tooltip: '图库识题'),
          Expanded(
            child: TextField(
              controller: controller, maxLines: 5, minLines: 1,
              enabled: !sending,
              decoration: InputDecoration(hintText: placeholder, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: sending
                ? const Icon(Icons.stop_rounded)
                : const Icon(Icons.send),
            style: sending
                ? IconButton.styleFrom(backgroundColor: Colors.red.shade400)
                : null,
            onPressed: sending ? onCancel : onSubmit,
          ),
        ],
      ),
    );
  }
}
