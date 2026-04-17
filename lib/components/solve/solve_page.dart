import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/current_subject_provider.dart';
import '../../providers/hint_provider.dart';
import '../../widgets/message_search_delegate.dart';
import '../../widgets/session_history_sheet.dart';
import '../../widgets/subject_bar.dart';
import '../../widgets/no_subject_hint.dart';
import '../../widgets/markdown_latex_view.dart';
import '../../widgets/mcp_status_indicator.dart';

class SolvePage extends ConsumerStatefulWidget {
  const SolvePage({super.key});
  @override
  ConsumerState<SolvePage> createState() => _SolvePageState();
}

class _SolvePageState extends ConsumerState<SolvePage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _useBroad = false;
  bool _sending = false;

  @override
  void dispose() { _inputCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  int? get _subjectId => ref.read(currentSubjectProvider)?.id;
  (int, String) get _key => (_subjectId!, 'solve');

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
    await ref.read(chatProvider(_key).notifier).sendMessage(text, mode: SessionType.solve, useBroad: _useBroad);
    _scrollToBottom();
  }

  void _cancelSending() {
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
    return Scaffold(
      appBar: AppBar(
        title: const SubjectBarTitle(),
        centerTitle: false,
        actions: const [McpStatusIndicator(), SizedBox(width: 8)],
      ),
      body: subject == null
          ? const NoSubjectHint()
          : _SolveBody(
              subjectId: subject.id,
              sending: _sending,
              useBroad: _useBroad,
              inputCtrl: _inputCtrl,
              scrollCtrl: _scrollCtrl,
              onBroadChanged: (v) => setState(() => _useBroad = v),
              onSubmit: _submit,
              onCancel: _cancelSending,
              onCamera: () => _pickAndOcr(ImageSource.camera),
              onGallery: () => _pickAndOcr(ImageSource.gallery),
            ),
    );
  }
}

class _SolveBody extends ConsumerWidget {
  final int subjectId;
  final bool sending;
  final bool useBroad;
  final TextEditingController inputCtrl;
  final ScrollController scrollCtrl;
  final ValueChanged<bool> onBroadChanged;
  final VoidCallback onSubmit, onCancel, onCamera, onGallery;

  const _SolveBody({required this.subjectId, required this.sending, required this.useBroad, required this.inputCtrl, required this.scrollCtrl, required this.onBroadChanged, required this.onSubmit, required this.onCancel, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (subjectId, 'solve');
    final chatState = ref.watch(chatProvider(key));
    return Column(
      children: [
        _SessionBar(subjectId: subjectId),
        Expanded(
          child: chatState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            data: (msgs) => msgs.isEmpty
                ? SingleChildScrollView(child: _EmptySolveHints(
                    subjectId: subjectId,
                    onTap: (h) => inputCtrl.text = h,
                  ))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) => _SolveBubble(message: msgs[i]),
                  ),
          ),
        ),
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
        _InputBar(controller: inputCtrl, sending: sending, onSubmit: onSubmit, onCancel: onCancel, onCamera: onCamera, onGallery: onGallery),
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
            onPressed: () => showSessionHistorySheet(context, ref, subjectId: subjectId, initialType: 'solve'),
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
            onPressed: () => ref.read(chatProvider((subjectId, 'solve')).notifier).newSession(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建对话', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// 解题气泡：AI 回复用等宽字体展示结构化内容
class _SolveBubble extends StatelessWidget {
  final ChatMessage message;
  const _SolveBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.95),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: isUser
            ? SelectableText(message.content, style: TextStyle(color: cs.onPrimary, height: 1.6))
            : MarkdownLatexView(
                data: message.content,
                textStyle: TextStyle(color: cs.onSurface),
                codeBackgroundColor: cs.surfaceContainerHighest,
              ),
      ),
    );
  }
}

class _EmptySolveHints extends ConsumerWidget {
  final int subjectId;
  final ValueChanged<String> onTap;
  const _EmptySolveHints({required this.subjectId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fallback = ['求解：f(x) = x² + 2x + 1，求极值', '证明：勾股定理', '计算：∫x²dx'];
    final hintsAsync = ref.watch(hintProvider((subjectId, false)));
    final hints = hintsAsync.valueOrNull ?? fallback;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('输入题目，AI 按步骤解题', style: Theme.of(context).textTheme.titleMedium),
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
  final VoidCallback onSubmit, onCancel, onCamera, onGallery;
  const _InputBar({required this.controller, required this.sending, required this.onSubmit, required this.onCancel, required this.onCamera, required this.onGallery});

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
              decoration: InputDecoration(hintText: '输入题目…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), isDense: true),
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
