import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/chat_message.dart';
import '../../../providers/chat_provider.dart';

class ChatTab extends ConsumerStatefulWidget {
  final int subjectId;
  const ChatTab({super.key, required this.subjectId});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  SessionType _mode = SessionType.qa;
  bool _useBroad = false;
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_mode == SessionType.mindmap) {
      await _generateMindMap();
      return;
    }
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    await ref.read(chatProvider(widget.subjectId).notifier).sendMessage(
          text, mode: _mode, useBroad: _useBroad,
        );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _generateMindMap() async {
    if (_sending) return;
    setState(() => _sending = true);
    await ref.read(chatProvider(widget.subjectId).notifier).generateMindMap();
    setState(() => _sending = false);
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    if (!mounted) return;
    final text = await ref.read(chatProvider(widget.subjectId).notifier).recognizeOcr(b64);
    if (text != null && text.isNotEmpty && mounted) {
      setState(() => _inputCtrl.text = text);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.subjectId));

    return Column(
      children: [
        _ModeBar(
          mode: _mode,
          useBroad: _useBroad,
          onModeChanged: (m) {
            setState(() {
              _mode = m;
              _inputCtrl.clear();
            });
            ref.read(chatProvider(widget.subjectId).notifier).newSession();
          },
          onBroadChanged: (v) => setState(() => _useBroad = v),
        ),
        _SessionHistoryBar(subjectId: widget.subjectId),
        Expanded(
          child: chatState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('错误：$e', style: const TextStyle(color: Colors.red)),
                  TextButton(
                    onPressed: () => ref.read(chatProvider(widget.subjectId).notifier).newSession(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) return _EmptyHints(mode: _mode, onTap: (h) => setState(() => _inputCtrl.text = h));
              if (_mode == SessionType.mindmap) return _MindMapView(messages: messages);
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: messages.length,
                itemBuilder: (_, i) => _MessageBubble(message: messages[i]),
              );
            },
          ),
        ),
        _InputBar(
          controller: _inputCtrl,
          mode: _mode,
          sending: _sending,
          onSubmit: _submit,
          onCamera: () => _pickAndOcr(ImageSource.camera),
          onGallery: () => _pickAndOcr(ImageSource.gallery),
        ),
      ],
    );
  }
}

// ── 模式选择栏 ────────────────────────────────────────────────────────────
class _ModeBar extends StatelessWidget {
  final SessionType mode;
  final bool useBroad;
  final ValueChanged<SessionType> onModeChanged;
  final ValueChanged<bool> onBroadChanged;
  const _ModeBar({required this.mode, required this.useBroad, required this.onModeChanged, required this.onBroadChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<SessionType>(
              segments: const [
                ButtonSegment(value: SessionType.qa,      label: Text('💬 问答')),
                ButtonSegment(value: SessionType.solve,   label: Text('🔢 解题')),
                ButtonSegment(value: SessionType.mindmap, label: Text('🗺 导图')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onModeChanged(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          if (mode != SessionType.mindmap) ...[
            const SizedBox(width: 4),
            Checkbox(value: useBroad, onChanged: (v) => onBroadChanged(v ?? false), visualDensity: VisualDensity.compact),
            const Text('通用知识', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ── 历史会话栏 ────────────────────────────────────────────────────────────
class _SessionHistoryBar extends ConsumerWidget {
  final int subjectId;
  const _SessionHistoryBar({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => _showSheet(context, ref),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('历史记录', style: TextStyle(fontSize: 13)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => ref.read(chatProvider(subjectId).notifier).newSession(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建对话', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistorySheet(subjectId: subjectId, ref: ref),
    );
  }
}

class _HistorySheet extends ConsumerWidget {
  final int subjectId;
  final WidgetRef ref;
  const _HistorySheet({required this.subjectId, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider(subjectId));
    return DraggableScrollableSheet(
      initialChildSize: 0.6, expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('对话历史', style: Theme.of(context).textTheme.titleMedium),
          ),
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
                          onTap: () {
                            ref.read(chatProvider(subjectId).notifier).loadSession(s.id);
                            Navigator.pop(context);
                          },
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

// ── 消息气泡 ──────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: TextStyle(color: isUser ? cs.onPrimary : cs.onSurface),
            ),
            if (message.sources != null && message.sources!.isNotEmpty)
              _SourcesWidget(sources: message.sources!),
          ],
        ),
      ),
    );
  }
}

class _SourcesWidget extends StatelessWidget {
  final List<MessageSource> sources;
  const _SourcesWidget({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('参考来源 (${sources.length})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: sources.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '· ${s.filename}（块 ${s.chunkIndex}）：${s.content.length > 60 ? '${s.content.substring(0, 60)}…' : s.content}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        )).toList(),
      ),
    );
  }
}

// ── 思维导图视图 ──────────────────────────────────────────────────────────
class _MindMapView extends StatelessWidget {
  final List<ChatMessage> messages;
  const _MindMapView({required this.messages});

  @override
  Widget build(BuildContext context) {
    final content = messages.lastWhere((m) => !m.isUser, orElse: () => messages.last).content;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // TODO: 接入 flutter_markdown 渲染 markmap 格式
            child: SelectableText(content),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () {/* TODO: 分享/导出 */},
            icon: const Icon(Icons.download),
            label: const Text('导出 Markdown'),
          ),
        ),
      ],
    );
  }
}

// ── 空状态提示 ────────────────────────────────────────────────────────────
class _EmptyHints extends StatelessWidget {
  final SessionType mode;
  final ValueChanged<String> onTap;
  const _EmptyHints({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hints = {
      SessionType.qa:      ['这道题的解题思路是什么？', '帮我总结第三章的重点', '这个概念怎么理解？'],
      SessionType.solve:   ['求解：f(x) = x² + 2x + 1，求极值', '证明：勾股定理', '计算：∫x²dx'],
      SessionType.mindmap: [],
    };
    final list = hints[mode] ?? [];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            if (mode == SessionType.mindmap)
              const Text('点击下方按钮生成思维导图')
            else ...[
              Text('试试这些问题', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...list.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => onTap(h),
                  child: Text(h, textAlign: TextAlign.center),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 输入栏 ────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final SessionType mode;
  final bool sending;
  final VoidCallback onSubmit;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _InputBar({
    required this.controller, required this.mode, required this.sending,
    required this.onSubmit, required this.onCamera, required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == SessionType.mindmap) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: sending ? null : onSubmit,
          icon: sending
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome),
          label: Text(sending ? '生成中…' : '生成思维导图'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: onCamera, tooltip: '拍照识题'),
          IconButton(icon: const Icon(Icons.image_outlined), onPressed: onGallery, tooltip: '图库识题'),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 5, minLines: 1,
              decoration: InputDecoration(
                hintText: mode == SessionType.solve ? '输入题目…' : '输入问题…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            onPressed: sending ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
