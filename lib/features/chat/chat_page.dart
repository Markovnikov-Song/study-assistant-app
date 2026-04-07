import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/current_subject_provider.dart';
import '../../widgets/subject_bar.dart';
import '../../widgets/no_subject_hint.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _useBroad = false;
  bool _sending = false;

  @override
  void dispose() { _inputCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  int? get _subjectId => ref.read(currentSubjectProvider)?.id;

  Future<void> _submit() async {
    final sid = _subjectId;
    if (sid == null || _sending) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    await ref.read(chatProvider(sid).notifier).sendMessage(text, mode: SessionType.qa, useBroad: _useBroad);
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    final sid = _subjectId;
    if (sid == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final b64 = base64Encode(await file.readAsBytes());
    if (!mounted) return;
    final text = await ref.read(chatProvider(sid).notifier).recognizeOcr(b64);
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
    return Scaffold(
      appBar: AppBar(title: const SubjectBarTitle(), centerTitle: false),
      body: subject == null
          ? const NoSubjectHint()
          : _ChatBody(
              subjectId: subject.id,
              useBroad: _useBroad,
              sending: _sending,
              inputCtrl: _inputCtrl,
              scrollCtrl: _scrollCtrl,
              onBroadChanged: (v) => setState(() => _useBroad = v),
              onSubmit: _submit,
              onCamera: () => _pickAndOcr(ImageSource.camera),
              onGallery: () => _pickAndOcr(ImageSource.gallery),
            ),
    );
  }
}

class _ChatBody extends ConsumerWidget {
  final int subjectId;
  final bool useBroad, sending;
  final TextEditingController inputCtrl;
  final ScrollController scrollCtrl;
  final ValueChanged<bool> onBroadChanged;
  final VoidCallback onSubmit, onCamera, onGallery;

  const _ChatBody({required this.subjectId, required this.useBroad, required this.sending,
    required this.inputCtrl, required this.scrollCtrl, required this.onBroadChanged,
    required this.onSubmit, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider(subjectId));
    return Column(
      children: [
        _SessionBar(subjectId: subjectId),
        Expanded(
          child: chatState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            data: (msgs) => msgs.isEmpty
                ? SingleChildScrollView(child: _EmptyHints(onTap: (h) => inputCtrl.text = h))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _Bubble(
                      message: msgs[i],
                      onDelete: () => ref.read(chatProvider(subjectId).notifier).deleteMessage(i),
                    ),
                  ),
          ),
        ),
        // 通用知识开关
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Checkbox(value: useBroad, onChanged: (v) => onBroadChanged(v ?? false), visualDensity: VisualDensity.compact),
              const Text('结合通用知识', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        _InputBar(controller: inputCtrl, sending: sending, placeholder: '输入问题…', onSubmit: onSubmit, onCamera: onCamera, onGallery: onGallery),
      ],
    );
  }
}

class _SessionBar extends ConsumerWidget {
  final int subjectId;
  const _SessionBar({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _showHistory(context, ref),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('历史记录', style: TextStyle(fontSize: 13)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => ref.read(chatProvider(subjectId).notifier).newSession(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建对话', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(subjectId: subjectId),
    );
  }
}

class _HistorySheet extends ConsumerWidget {
  final int subjectId;
  const _HistorySheet({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider(subjectId));
    return DraggableScrollableSheet(
      initialChildSize: 0.6, expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('对话历史', style: Theme.of(context).textTheme.titleMedium)),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (sessions) => sessions.isEmpty
                  ? const Center(child: Text('暂无历史记录'))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: sessions.length,
                      itemBuilder: (_, i) {
                        final s = sessions[i];
                        return ListTile(
                          leading: Text(s.typeLabel, style: const TextStyle(fontSize: 18)),
                          title: Text(s.title ?? '未命名对话'),
                          subtitle: Text('${s.createdAt.month}-${s.createdAt.day} ${s.createdAt.hour}:${s.createdAt.minute.toString().padLeft(2, '0')}'),
                          onTap: () { ref.read(chatProvider(subjectId).notifier).loadSession(s.id); Navigator.pop(context); },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onDelete;
  const _Bubble({required this.message, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptions(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: isUser ? cs.primary : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: SelectableText(message.content, style: TextStyle(color: isUser ? cs.onPrimary : cs.onSurface)),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除此消息', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); onDelete!(); },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHints extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _EmptyHints({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const hints = ['这道题的解题思路是什么？', '帮我总结第三章的重点', '这个概念怎么理解？'];
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
  final VoidCallback onSubmit, onCamera, onGallery;
  const _InputBar({required this.controller, required this.sending, required this.placeholder, required this.onSubmit, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: onCamera, tooltip: '拍照识题'),
          IconButton(icon: const Icon(Icons.image_outlined), onPressed: onGallery, tooltip: '图库识题'),
          Expanded(
            child: TextField(
              controller: controller, maxLines: 5, minLines: 1,
              decoration: InputDecoration(hintText: placeholder, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
            onPressed: sending ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
