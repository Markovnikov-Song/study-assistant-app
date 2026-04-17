// lib/features/skill_creation/dialog_creation_page.dart
// 对话式 Skill 创建页面（聊天气泡式交互）
// 任务 27：对话式 Skill 创建 UI 页面

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/skill/dialog_skill_creation_service.dart';
import '../../core/skill/marketplace_models.dart';
import '../../core/skill/skill_model.dart';
import 'skill_draft_preview.dart';

// ── 消息气泡数据模型 ───────────────────────────────────────────────────────────

enum _BubbleRole { assistant, user }

class _ChatBubble {
  final _BubbleRole role;
  final String text;

  const _ChatBubble({required this.role, required this.text});
}

// ── DialogCreationPage ────────────────────────────────────────────────────────

class DialogCreationPage extends ConsumerStatefulWidget {
  const DialogCreationPage({super.key});

  @override
  ConsumerState<DialogCreationPage> createState() =>
      _DialogCreationPageState();
}

class _DialogCreationPageState extends ConsumerState<DialogCreationPage> {
  final _service = DialogSkillCreationService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_ChatBubble> _bubbles = [];
  String? _sessionId;
  bool _loading = false;
  bool _isComplete = false;
  DialogTurn? _lastTurn;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    // 放弃未完成的会话
    if (_sessionId != null && !_isComplete) {
      _service.deleteSession(_sessionId!).ignore();
    }
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _loading = true);
    try {
      final turn = await _service.startSession();
      _sessionId = turn.sessionId;
      _lastTurn = turn;
      setState(() {
        _bubbles.add(_ChatBubble(
          role: _BubbleRole.assistant,
          text: turn.question,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      _showError('启动失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendAnswer() async {
    final answer = _inputController.text.trim();
    if (answer.isEmpty || _sessionId == null || _loading) return;

    _inputController.clear();
    setState(() {
      _bubbles.add(_ChatBubble(role: _BubbleRole.user, text: answer));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final turn = await _service.sendAnswer(_sessionId!, answer);
      _lastTurn = turn;
      setState(() {
        _bubbles.add(_ChatBubble(
          role: _BubbleRole.assistant,
          text: turn.question,
        ));
        _isComplete = turn.isComplete;
      });
      _scrollToBottom();

      // 收集到足够信息后展示草稿预览
      if (turn.isComplete && turn.draftPreview != null) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          _showDraftPreview(turn.draftPreview!);
        }
      }
    } catch (e) {
      _showError('发送失败：$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showDraftPreview(SkillDraft draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkillDraftPreview(
          draft: draft,
          sessionId: _sessionId!,
          onConfirmed: () {
            setState(() => _isComplete = true);
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          onContinue: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建我的学习方法'),
        actions: [
          if (_lastTurn?.draftPreview != null)
            TextButton(
              onPressed: () => _showDraftPreview(_lastTurn!.draftPreview!),
              child: const Text('预览'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 进度提示
          if (_loading)
            const LinearProgressIndicator(),

          // 对话气泡列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _bubbles.length,
              itemBuilder: (context, index) {
                final bubble = _bubbles[index];
                return _BubbleWidget(bubble: bubble);
              },
            ),
          ),

          // 输入区域
          if (!_isComplete)
            _InputBar(
              controller: _inputController,
              loading: _loading,
              onSend: _sendAnswer,
            ),

          // 完成提示
          if (_isComplete)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _lastTurn?.draftPreview != null
                      ? () => _showDraftPreview(_lastTurn!.draftPreview!)
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('查看并确认'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 气泡 Widget ───────────────────────────────────────────────────────────────

class _BubbleWidget extends StatelessWidget {
  final _ChatBubble bubble;

  const _BubbleWidget({required this.bubble});

  @override
  Widget build(BuildContext context) {
    final isAssistant = bubble.role == _BubbleRole.assistant;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAssistant) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAssistant
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAssistant ? 4 : 16),
                  bottomRight: Radius.circular(isAssistant ? 16 : 4),
                ),
              ),
              child: Text(
                bubble.text,
                style: TextStyle(
                  color: isAssistant
                      ? theme.colorScheme.onSurface
                      : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (!isAssistant) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 16, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 输入栏 ─────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '输入你的回答…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: loading ? null : onSend,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            tooltip: '发送',
          ),
        ],
      ),
    );
  }
}
