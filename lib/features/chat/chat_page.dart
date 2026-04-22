import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat_message.dart';
import '../../models/subject.dart';
import '../../providers/chat_provider.dart';
import '../../providers/current_session_provider.dart';
import '../../providers/hint_provider.dart';
import '../../providers/multi_select_provider.dart';
import '../../providers/subject_provider.dart';
import '../../services/intent_detector.dart';
import '../../widgets/message_search_delegate.dart';
import '../../widgets/scene_card.dart';
import '../../widgets/session_history_sheet.dart';
import '../../widgets/markdown_latex_view.dart';
import '../../widgets/mcp_status_indicator.dart';
import '../../components/notebook/widgets/notebook_picker_sheet.dart';
import '../../core/theme/app_colors.dart';

// ─── ChatPage（参数化，支持通用/学科/任务三种场景）────────────

class ChatPage extends ConsumerStatefulWidget {
  final String? chatId;     // null �?通用对话（根路由 /�?
  final int? subjectId;     // 学科专属对话
  final String? taskId;     // 任务对话

  const ChatPage({super.key, this.chatId, this.subjectId, this.taskId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _useHybrid = false;
  bool _sending = false;
  final _intentDetector = RuleBasedIntentDetector();

  // chatKey：通用对话�?'general'，学科对话用 subjectId 字符串，任务对话�?chatId
  String get _chatKey {
    if (widget.subjectId != null) return widget.subjectId!.toString();
    if (widget.chatId != null) return widget.chatId!;
    return 'general';
  }

  String get _sessionType {
    if (widget.subjectId != null) return 'subject';
    if (widget.taskId != null) return 'task';
    return 'qa';
  }

  (String, String) get _key => (_chatKey, _sessionType);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentSessionProvider.notifier).state = Session(
          id: _chatKey,
          title: widget.subjectId != null ? '学科对话' : '通用对话',
          updatedAt: DateTime.now(),
          subjectId: widget.subjectId?.toString(),
          taskId: widget.taskId,
        );
      }
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _bindSendingCallback() {
    ref.read(chatProvider(_key).notifier).onSendingChanged = (v) {
      if (mounted) setState(() => _sending = v);
    };
  }

  // 自动检测到的学科 ID（静默归类用）
  int? _autoDetectedSubjectId;

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _bindSendingCallback();

    await ref.read(chatProvider(_key).notifier).sendMessage(
      text,
      mode: SessionType.qa,
      useHybrid: _useHybrid,
      overrideSubjectId: _autoDetectedSubjectId,
    );
    _scrollToBottom();

    // 意图识别（仅通用对话触发）
    if (widget.subjectId == null && widget.taskId == null) {
      _detectSubjectSilently(text);
    }
  }

  void _detectSubjectSilently(String userInput) async {
    final subjects = ref.read(subjectsProvider).valueOrNull;
    final intent = await _intentDetector.detect(userInput, subjects: subjects);
    if (!mounted) return;

    if (intent.type == IntentType.subject) {
      final subjectId = intent.params['subjectId'] as int?;
      final subjectName = intent.params['subjectName'] as String? ?? '';
      if (subjectId != null && subjectId != _autoDetectedSubjectId) {
        setState(() => _autoDetectedSubjectId = subjectId);
        // 显示一个轻提示，不打断对话
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已自动归类到「$subjectName」'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              width: 220,
            ),
          );
        }
      }
    }

    // 其他意图（规划/工具/spec）仍然弹 SceneCard
    if (intent.type != IntentType.subject && intent.type != IntentType.none) {
      final sceneCardData = _buildSceneCardData(intent);
      if (sceneCardData == null) return;
      final sceneMsg = ChatMessage.local(
        role: MessageRole.assistant,
        content: '',
        type: MessageType.sceneCard,
        sceneCardData: sceneCardData,
      );
      ref.read(chatProvider(_key).notifier).appendMessage(sceneMsg);
    }
  }

  SceneCardData? _buildSceneCardData(DetectedIntent intent) {
    switch (intent.type) {
      case IntentType.subject:
        return SceneCardData(
          sceneType: SceneType.subject,
          title: '检测到「${intent.params['subjectName']}」相关问题',
          subtitle: '切换到专属对话获得更精准的辅导',
          confirmLabel: '切换',
          dismissLabel: '继续通用对话',
          payload: intent.params,
        );
      case IntentType.planning:
        return SceneCardData(
          sceneType: SceneType.planning,
          title: '检测到学习规划需求',
          subtitle: '为你生成结构化的学习计划',
          confirmLabel: '生成计划',
          dismissLabel: '稍后再说',
          payload: intent.params,
        );
      case IntentType.tool:
        return SceneCardData(
          sceneType: SceneType.tool,
          title: '跳转到${intent.params['toolName']}？',
          confirmLabel: '一键跳转',
          dismissLabel: '在对话中继续',
          payload: intent.params,
        );
      case IntentType.spec:
        return SceneCardData(
          sceneType: SceneType.spec,
          title: '检测到大型学习任务',
          subtitle: '启动 Spec 规划模式进行系统性拆解',
          confirmLabel: '启动',
          dismissLabel: '普通对话',
          payload: intent.params,
        );
      case IntentType.none:
        return null;
    }
  }

  void _cancelSending() {
    ref.read(chatProvider(_key).notifier).cancelSending();
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    final b64 = base64Encode(await file.readAsBytes());
    if (!mounted) return;
    final text = await ref.read(chatProvider(_key).notifier).recognizeOcr(b64);
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
    final multiSelect = ref.watch(multiSelectProvider);
    final selectedCount = multiSelect.selectedMessageIds.length;

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
    } else if (widget.subjectId != null) {
      // 学科专属对话顶栏：显示学科名 + 返回按钮
      final subjectsAsync = ref.watch(subjectsProvider);
      final subjectName = subjectsAsync.valueOrNull
              ?.firstWhere(
                (s) => s.id == widget.subjectId,
                orElse: () => Subject(id: 0, name: '学科对话', createdAt: DateTime.now()),
              )
              .name ??
          '学科对话';
      appBar = AppBar(
        title: Text(subjectName),
        centerTitle: false,
        leading: const BackButton(),
      );
    } else if (widget.taskId != null) {
      // 任务对话顶栏：显示任务名 + 返回按钮
      appBar = AppBar(
        title: Text(widget.taskId!),
        centerTitle: false,
        leading: const BackButton(),
      );
    } else {
      // 通用对话顶栏：「学习助手」
      appBar = AppBar(
        title: const Text('学习助手'),
        centerTitle: false,
        actions: [
          const McpStatusIndicator(),
          const SizedBox(width: 8),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: appBar,
      body: Stack(
        children: [
          // 背景装饰
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                        .withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          _ChatBody(
            chatKey: _chatKey,
            sessionType: _sessionType,
            subjectId: widget.subjectId ?? 0,
            isGeneral: widget.subjectId == null && widget.taskId == null,
            useHybrid: _useHybrid,
            sending: _sending,
            inputCtrl: _inputCtrl,
            scrollCtrl: _scrollCtrl,
            onHybridChanged: (v) => setState(() => _useHybrid = v),
            onSubmit: _submit,
            onCancel: _cancelSending,
            onCamera: () => _pickAndOcr(ImageSource.camera),
            onGallery: () => _pickAndOcr(ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

// ─── _ChatBody ────────────────────────────────────────────────

class _ChatBody extends ConsumerWidget {
  final String chatKey;
  final String sessionType;
  final int subjectId;
  final bool isGeneral;
  final bool useHybrid, sending;
  final TextEditingController inputCtrl;
  final ScrollController scrollCtrl;
  final ValueChanged<bool> onHybridChanged;
  final VoidCallback onSubmit, onCancel, onCamera, onGallery;

  const _ChatBody({
    required this.chatKey,
    required this.sessionType,
    required this.subjectId,
    required this.isGeneral,
    required this.useHybrid,
    required this.sending,
    required this.inputCtrl,
    required this.scrollCtrl,
    required this.onHybridChanged,
    required this.onSubmit,
    required this.onCancel,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (chatKey, sessionType);
    final chatState = ref.watch(chatProvider(key));
    final multiSelect = ref.watch(multiSelectProvider);

    return Column(
      children: [
        _SessionBar(chatKey: chatKey, sessionType: sessionType, subjectId: subjectId),
        Expanded(
          child: chatState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            data: (msgs) => msgs.isEmpty
                ? SingleChildScrollView(
                    child: _EmptyHints(subjectId: subjectId, onTap: (h) => inputCtrl.text = h),
                  )
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
                      final msg = msgs[i];
                      if (msg.type == MessageType.sceneCard && msg.sceneCardData != null) {
                        return SceneCard(
                          key: ValueKey('scene_${msg.id}'),
                          data: msg.sceneCardData!,
                          onConfirm: () => _handleSceneCardConfirm(msg, ref, context, key),
                          onDismiss: () {
                            msg.sceneCardData!.dismissed = true;
                            ref.read(chatProvider(key).notifier).refreshState();
                          },
                        );
                      }
                      if (msg.type == MessageType.sceneCard) {
                        return const SizedBox.shrink();
                      }
                      return _Bubble(
                        message: msg,
                        onDelete: multiSelect.isActive
                            ? null
                            : () => ref.read(chatProvider(key).notifier).deleteMessage(i),
                      );
                    },
                  ),
          ),
        ),
        if (!multiSelect.isActive) ...[
          // 通用对话不显示「结合通用知识」checkbox（没有知识库�?
          if (!isGeneral)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Row(
                children: [
                  Checkbox(
                    value: useHybrid,
                    onChanged: (v) => onHybridChanged(v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Text('结合通用知识', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: '优先检索知识库，检索不到时自动用通用知识回答',
                    child: Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          _InputBar(
            controller: inputCtrl,
            sending: sending,
            placeholder: '输入问题…',
            onSubmit: onSubmit,
            onCancel: onCancel,
            onCamera: onCamera,
            onGallery: onGallery,
          ),
        ] else
          _MultiSelectBar(
            subjectId: subjectId,
            messages: chatState.maybeWhen(data: (msgs) => msgs, orElse: () => []),
          ),
      ],
    );
  }
}

// ─── SceneCard 确认处理 ───────────────────────────────────────

void _handleSceneCardConfirm(
  ChatMessage msg,
  WidgetRef ref,
  BuildContext context,
  (String, String) key,
) {
  final data = msg.sceneCardData;
  if (data == null) return;
  data.dismissed = true;
  ref.read(chatProvider(key).notifier).refreshState();

  switch (data.sceneType) {
    case SceneType.subject:
      final subjectId = data.payload['subjectId'] as int?;
      if (subjectId != null) {
        context.push('/chat/${DateTime.now().millisecondsSinceEpoch}/subject/$subjectId');
      }
    case SceneType.planning:
      // 暂时跳转到通用对话，后续实现规划流程
      break;
    case SceneType.tool:
      final route = data.payload['toolRoute'] as String?;
      if (route != null) context.push(route);
    case SceneType.spec:
      context.push('/spec');
  }
}

// ─── _SessionBar ──────────────────────────────────────────────

class _SessionBar extends ConsumerWidget {
  final String chatKey;
  final String sessionType;
  final int subjectId;
  const _SessionBar({required this.chatKey, required this.sessionType, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (chatKey, sessionType);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
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
    showSessionHistorySheet(
      context,
      ref,
      subjectId: subjectId,
      initialType: sessionType == 'qa' ? 'qa' : null,
    );
  }
}

// ─── _Bubble ──────────────────────────────────────────────────

class _Bubble extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onDelete;
  const _Bubble({required this.message, this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final multiSelect = ref.watch(multiSelectProvider);
    final isSelected = multiSelect.selectedMessageIds.contains(message.id);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (!multiSelect.isActive) {
            ref.read(multiSelectProvider.notifier).activate(message.id);
          } else {
            ref.read(multiSelectProvider.notifier).toggle(message.id);
          }
        },
        onTap: () {
          if (multiSelect.isActive) ref.read(multiSelectProvider.notifier).toggle(message.id);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  )
                : null,
            color: isUser ? null : (isDark ? AppColors.surfaceDark : AppColors.surface),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 18),
            ),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : (isUser
                    ? null
                    : Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      )),
            boxShadow: [
              BoxShadow(
                color: isUser
                    ? AppColors.primary.withOpacity(0.25)
                    : Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isUser
                  ? (multiSelect.isActive
                      ? Text(
                          message.content,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.5,
                            fontSize: 15,
                          ),
                        )
                      : SelectableText(
                          message.content,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.5,
                            fontSize: 15,
                          ),
                        ))
                  : MarkdownLatexView(
                      data: message.content,
                      textStyle: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        height: 1.6,
                        fontSize: 15,
                      ),
                      codeBackgroundColor: isDark
                          ? AppColors.surfaceContainerHighDark
                          : AppColors.surfaceContainerHigh,
                    ),
              if (!isUser && message.sources != null && message.sources!.isNotEmpty)
                _SourcesWidget(sources: message.sources!),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _TypingIndicator ─────────────────────────────────────────

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
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
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

// ─── _MultiSelectBar ──────────────────────────────────────────

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

// ─── _SourcesWidget ───────────────────────────────────────────

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
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${s.filename}  第${s.chunkIndex + 1}段',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  s.content.length > 100 ? '${s.content.substring(0, 100)}…' : s.content,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

// ─── _EmptyHints ──────────────────────────────────────────────

class _EmptyHints extends ConsumerWidget {
  final int subjectId;
  final ValueChanged<String> onTap;
  const _EmptyHints({required this.subjectId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> hints;
    if (subjectId == 0) {
      // 通用对话默认提示（不依赖知识库）
      hints = const ['今天学了什么？', '帮我解释一个概念', '我想制定学习计划'];
    } else {
      final hintsAsync = ref.watch(hintProvider((subjectId, true)));
      hints = hintsAsync.valueOrNull ??
          const ['这道题的解题思路是什么？', '帮我总结这章的重点', '这个概念怎么理解？'];
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 装饰图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                        .withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 48,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '试试这些问题',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...hints.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.surfaceElevatedDark : AppColors.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onTap(h),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        h,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── _InputBar ────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final String placeholder;
  final VoidCallback onSubmit, onCancel, onCamera, onGallery;
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.placeholder,
    required this.onSubmit,
    required this.onCancel,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 拍照按钮
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceElevatedDark.withOpacity(0.5)
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt_outlined,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              onPressed: sending ? null : onCamera,
              tooltip: '拍照识题',
            ),
          ),
          const SizedBox(width: 8),
          // 图库按钮
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceElevatedDark.withOpacity(0.5)
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.image_outlined,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              onPressed: sending ? null : onGallery,
              tooltip: '图库识题',
            ),
          ),
          const SizedBox(width: 12),
          // 输入框
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
              child: TextField(
                controller: controller,
                maxLines: 5,
                minLines: 1,
                enabled: !sending,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 发送按钮
          Container(
            decoration: BoxDecoration(
              gradient: sending
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
              color: sending ? Colors.red.shade400 : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: sending
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: IconButton(
              icon: Icon(
                sending ? Icons.stop_rounded : Icons.send_rounded,
                color: Colors.white,
              ),
              onPressed: sending ? onCancel : onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}
