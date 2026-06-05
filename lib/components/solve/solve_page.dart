// ignore_for_file: deprecated_member_use, unintended_html_in_doc_comment

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/network/dio_client.dart';
import '../../core/storage/storage_service.dart';
import '../../features/solve/models/solve_session.dart';
import '../../features/solve/services/solve_history_service.dart';
import '../../features/solve/widgets/solve_history_sheet.dart';
import '../../models/notebook.dart';
import '../../models/solve_session_model.dart';
import '../../models/subject.dart';
import '../../providers/notebook_provider.dart';
import '../../providers/solve_prefill_provider.dart';
import '../../providers/subject_provider.dart';
import '../../services/background_task_service.dart';
import '../../services/notebook_service.dart';
import '../../services/review_service.dart';
import '../../services/solve_sse_client.dart';
import '../../widgets/cot_collapsible_view.dart';
import '../../widgets/ai_task_status_bar.dart';
import '../../widgets/markdown_latex_view.dart';
import '../../widgets/multimodal_input_bar.dart';
import '../../widgets/solve_result_action_bar.dart';

// ── 解题会话 StateNotifier ────────────────────────────────────────────────────

class _SolveSessionNotifier extends StateNotifier<SolveSessionModel> {
  _SolveSessionNotifier() : super(SolveSessionModel.empty());

  StreamSubscription<SolveSSEEvent>? _subscription;
  bool _backgroundTaskActive = false;

  /// 开始新的解题请求（首次或追问）
  Future<void> send({
    required Map<String, dynamic> payload,
    required Dio dio,
  }) async {
    if (state.isStreaming) {
      cancelStreaming();
    }
    // 追加用户消息气泡
    final images = (payload['images'] as List?)?.cast<String>() ?? [];
    final text = payload['supplement_text'] as String? ?? '';
    final userMsg = SolveMessage(
      role: 'user',
      content: text,
      imageBase64List: images.isEmpty ? null : images,
    );
    state = state.addMessage(userMsg).copyWith(isStreaming: true);

    // 追加空 AI 气泡（流式填充）
    final aiMsg = const SolveMessage(role: 'assistant', content: '');
    state = state.addMessage(aiMsg);
    await _beginBackgroundTask();

    // 构建请求 payload（追问时注入历史）
    final history = state
        .toLLMHistory()
        .where(
          (m) =>
              m['role'] != 'assistant' || (m['content'] as String).isNotEmpty,
        )
        .toList();
    // 去掉刚追加的空 AI 消息
    final historyForRequest = history.length >= 2
        ? history.sublist(0, history.length - 1)
        : <Map<String, dynamic>>[];

    final requestPayload = {
      'text': text,
      // 追问时传递后端 session_id 以复用会话
      'session_id': state.backendSessionId,
      'images': images,
      'supplement_text': text,
      'history': historyForRequest,
    };

    final token = await StorageService.instance.getToken() ?? '';
    final client = SolveSSEClient(dio);

    _subscription?.cancel();
    _subscription = client
        .connect(
          url: '/api/cas/dispatch',
          payload: requestPayload,
          token: token,
        )
        .listen(
          _onEvent,
          onError: (e) => _onError(e.toString()),
          onDone: () {
            _finishStreaming();
          },
        );
  }

  void _onEvent(SolveSSEEvent event) {
    switch (event) {
      case SolveTokenEvent(:final text):
        // 检测是否为 [CHART] 图表事件（JSON 格式：{"content":"[CHART]","image_base64":"..."}）
        // SolveSSEClient 已将 JSON 解析，[CHART] token 会直接作为 text 传入
        // 但图表事件的完整 JSON 需要在 SolveSSEClient 层处理，这里通过特殊标记检测
        if (text == '[CHART]') {
          // [CHART] 标记本身不追加到内容，图表数据由 SolveChartEvent 携带
          // 此处为兼容处理：若 SSE 客户端未扩展，则忽略该 token
          return;
        }
        state = state.updateLastMessage(text);
      case SolveDoneEvent(:final sessionId):
        // 从 [DONE] 事件中提取后端 session_id
        if (sessionId != null) {
          state = state.copyWith(
            backendSessionId: sessionId,
            isStreaming: false,
          );
        } else {
          state = state.copyWith(isStreaming: false);
        }
        unawaited(_endBackgroundTask());
      case SolveChartEvent(:final imageBase64):
        // 将图表数据存储到当前 AI 消息
        _attachChartToLastMessage(imageBase64);
      case SolveErrorEvent(:final message):
        _onError(message);
    }
  }

  /// 将图表 Base64 附加到最后一条 AI 消息
  void _attachChartToLastMessage(String imageBase64) {
    if (state.messages.isEmpty) return;
    final last = state.messages.last;
    if (last.role != 'assistant') return;
    final updated = last.copyWith(chartBase64: imageBase64);
    final msgs = [
      ...state.messages.sublist(0, state.messages.length - 1),
      updated,
    ];
    state = state.copyWith(messages: msgs);
  }

  void _onError(String message) {
    // 将错误追加到最后一条 AI 消息
    if (state.messages.isNotEmpty && state.messages.last.role == 'assistant') {
      final last = state.messages.last;
      final updated = last.copyWith(
        content: last.content.isEmpty
            ? '⚠️ $message'
            : '${last.content}\n\n⚠️ $message',
      );
      final msgs = [
        ...state.messages.sublist(0, state.messages.length - 1),
        updated,
      ];
      state = state.copyWith(messages: msgs, isStreaming: false);
    } else {
      state = state.copyWith(isStreaming: false);
    }
    unawaited(_endBackgroundTask());
  }

  Future<void> _beginBackgroundTask() async {
    if (_backgroundTaskActive) return;
    _backgroundTaskActive = true;
    await BackgroundTaskService.instance.startTask(
      BackgroundTaskType.aiStreaming,
    );
  }

  Future<void> _endBackgroundTask() async {
    if (!_backgroundTaskActive) return;
    _backgroundTaskActive = false;
    await BackgroundTaskService.instance.endTask(
      BackgroundTaskType.aiStreaming,
    );
  }

  void _finishStreaming() {
    if (state.isStreaming) {
      state = state.copyWith(isStreaming: false);
    }
    unawaited(_endBackgroundTask());
  }

  void cancelStreaming() {
    _subscription?.cancel();
    _subscription = null;
    if (state.messages.isNotEmpty && state.messages.last.role == 'assistant') {
      final last = state.messages.last;
      if (last.content.isEmpty) {
        state = state.copyWith(
          messages: state.messages.sublist(0, state.messages.length - 1),
          isStreaming: false,
        );
      } else {
        final updated = last.copyWith(
          content: '${last.content}\n\n_已停止。你可以补充条件后继续追问。_',
        );
        state = state.copyWith(
          messages: [
            ...state.messages.sublist(0, state.messages.length - 1),
            updated,
          ],
          isStreaming: false,
        );
      }
    } else {
      state = state.copyWith(isStreaming: false);
    }
    unawaited(_endBackgroundTask());
  }

  /// 从历史记录恢复会话
  ///
  /// 将 [SolveHistoryMessage] 列表转换为 [SolveMessage] 并恢复到状态，
  /// 同时设置 [backendSessionId] 以便后续追问复用同一会话。
  void restoreFromHistory(
    int backendSessionId,
    List<SolveHistoryMessage> messages,
  ) {
    _subscription?.cancel();
    final solveMessages = messages.map((m) {
      return SolveMessage(
        role: m.role,
        content: m.content,
        imageBase64List: m.images.isEmpty ? null : m.images,
      );
    }).toList();

    state = SolveSessionModel(
      sessionId: state.sessionId,
      backendSessionId: backendSessionId,
      imageBase64List: const [],
      ocrText: '',
      messages: solveMessages,
      isThinkingExpanded: false,
      isStreaming: false,
    );
  }

  /// 切换 CoT 展开/折叠状态
  void toggleThinking() {
    state = state.copyWith(isThinkingExpanded: !state.isThinkingExpanded);
  }

  /// 将指定消息标记为已收藏到笔记本
  void markSavedToNotebook(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= state.messages.length) return;
    final msgs = List<SolveMessage>.from(state.messages);
    msgs[messageIndex] = msgs[messageIndex].copyWith(isSavedToNotebook: true);
    state = state.copyWith(messages: msgs);
  }

  /// 将指定消息标记为已加入错题本
  void markSavedToMistakes(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= state.messages.length) return;
    final msgs = List<SolveMessage>.from(state.messages);
    msgs[messageIndex] = msgs[messageIndex].copyWith(isSavedToMistakes: true);
    state = state.copyWith(messages: msgs);
  }

  /// 开始新会话
  void newSession() {
    _subscription?.cancel();
    unawaited(_endBackgroundTask());
    state = SolveSessionModel.empty();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_endBackgroundTask());
    super.dispose();
  }
}

final _solveSessionProvider =
    StateNotifierProvider.autoDispose<_SolveSessionNotifier, SolveSessionModel>(
      (ref) => _SolveSessionNotifier(),
    );

// ── SolvePage ─────────────────────────────────────────────────────────────────

/// 多模态解题专页。
///
/// 支持：
/// - 图片 + 文字输入（MultimodalInputBar）
/// - 流式 SSE 接收（SolveSSEClient）
/// - CoT 思维链折叠（CoTCollapsibleView）
/// - 解题结果入库（笔记本 / 错题本）
class SolvePage extends ConsumerStatefulWidget {
  const SolvePage({super.key});

  @override
  ConsumerState<SolvePage> createState() => _SolvePageState();
}

class _SolvePageState extends ConsumerState<SolvePage> {
  final _scrollCtrl = ScrollController();
  final _dio = DioClient.instance.dio;

  @override
  void initState() {
    super.initState();
    // 检查是否有从助教页面传来的预填文字
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final imagePreFill = ref.read(solveImagePreFillProvider);
      if (imagePreFill.isNotEmpty) {
        ref.read(solveImagePreFillProvider.notifier).state = const [];
        ref
            .read(_solveSessionProvider.notifier)
            .send(
              payload: {
                'text': '',
                'images': imagePreFill,
                'supplement_text': '',
              },
              dio: _dio,
            );
        return;
      }

      final preFill = ref.read(solvePreFillProvider);
      if (preFill != null && preFill.isNotEmpty) {
        ref.read(solvePreFillProvider.notifier).state = null;
        // 预填文字作为纯文字消息发送
        ref
            .read(_solveSessionProvider.notifier)
            .send(
              payload: {
                'text': preFill,
                'images': <String>[],
                'supplement_text': preFill,
              },
              dio: _dio,
            );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
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

  Future<void> _handleSend(Map<String, dynamic> payload) async {
    await ref
        .read(_solveSessionProvider.notifier)
        .send(payload: payload, dio: _dio);
    _scrollToBottom();
  }

  /// 打开历史记录面板
  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SolveHistorySheet(onSessionSelected: _restoreSession),
    );
  }

  /// 从历史记录恢复会话
  Future<void> _restoreSession(SolveHistorySession session) async {
    try {
      final messages = await SolveHistoryService().fetchSession(session.id);
      if (!mounted) return;
      ref
          .read(_solveSessionProvider.notifier)
          .restoreFromHistory(session.id, messages);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载历史记录失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(_solveSessionProvider);

    // 流式接收时持续滚动到底部
    if (session.isStreaming) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '解题助手',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // 历史记录按钮
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史记录',
            onPressed: _openHistorySheet,
          ),
          // 新建会话按钮
          TextButton.icon(
            onPressed: () =>
                ref.read(_solveSessionProvider.notifier).newSession(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: session.messages.isEmpty
                ? _EmptySolveHints(
                    onTap: (hint) => _handleSend({
                      'text': hint,
                      'images': <String>[],
                      'supplement_text': hint,
                    }),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount:
                        session.messages.length +
                        (session.isStreaming &&
                                session.messages.isNotEmpty &&
                                session.messages.last.role == 'assistant' &&
                                session.messages.last.content.isEmpty
                            ? 0
                            : 0),
                    itemBuilder: (_, i) {
                      final msg = session.messages[i];
                      if (msg.role == 'user') {
                        return _UserBubble(message: msg);
                      } else {
                        // 判断是否是最后一条正在流式接收的 AI 消息
                        final isStreamingThis =
                            session.isStreaming &&
                            i == session.messages.length - 1;
                        final sourceMessage = _previousUserMessage(
                          session.messages,
                          i,
                        );
                        return _AiBubble(
                          key: ValueKey('ai_$i'),
                          message: msg,
                          sourceMessage: sourceMessage,
                          messageIndex: i,
                          isStreaming: isStreamingThis,
                          isThinkingExpanded: session.isThinkingExpanded,
                          onToggleThinking: () => ref
                              .read(_solveSessionProvider.notifier)
                              .toggleThinking(),
                          onSavedToNotebook: () => ref
                              .read(_solveSessionProvider.notifier)
                              .markSavedToNotebook(i),
                          onSavedToMistakes: () => ref
                              .read(_solveSessionProvider.notifier)
                              .markSavedToMistakes(i),
                        );
                      }
                    },
                  ),
          ),
          AiTaskStatusBar(
            active: session.isStreaming,
            title: '正在解题',
            subtitle: '可以随时停止，已生成的步骤会保留。',
            onCancel: () =>
                ref.read(_solveSessionProvider.notifier).cancelStreaming(),
            tone: AiTaskTone.secondary,
          ),
          // 底部多模态输入栏
          MultimodalInputBar(
            onSend: _handleSend,
            hintText: '输入题目或补充说明…',
            isSending: session.isStreaming,
            onCancel: () =>
                ref.read(_solveSessionProvider.notifier).cancelStreaming(),
          ),
        ],
      ),
    );
  }

  SolveMessage? _previousUserMessage(List<SolveMessage> messages, int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (messages[i].role == 'user') return messages[i];
    }
    return null;
  }
}

// ── 用户消息气泡 ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final SolveMessage message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final images = message.imageBase64List ?? [];

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.secondary],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图片缩略图网格（最多 2 列）
            if (images.isNotEmpty) ...[
              _ImageThumbnailGrid(
                base64Images: images,
                onTap: (index) => _openFullscreen(context, images, index),
              ),
              if (message.content.isNotEmpty) const SizedBox(height: 8),
            ],
            // 文字内容
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(
          base64Images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ── 图片缩略图网格 ─────────────────────────────────────────────────────────────

class _ImageThumbnailGrid extends StatelessWidget {
  final List<String> base64Images;
  final void Function(int index) onTap;

  const _ImageThumbnailGrid({required this.base64Images, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: base64Images.length,
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => onTap(i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _decodeBase64(base64Images[i]),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  /// 解码 Base64 图片，处理可能带有 data URI 前缀的情况
  static Uint8List _decodeBase64(String b64) {
    final data = b64.contains(',') ? b64.split(',').last : b64;
    return base64Decode(data);
  }
}

// ── AI 消息气泡 ───────────────────────────────────────────────────────────────

class _AiBubble extends ConsumerWidget {
  final SolveMessage message;
  final SolveMessage? sourceMessage;
  final int messageIndex;
  final bool isStreaming;
  final bool isThinkingExpanded;
  final VoidCallback onToggleThinking;
  final VoidCallback onSavedToNotebook;
  final VoidCallback onSavedToMistakes;

  const _AiBubble({
    super.key,
    required this.message,
    required this.sourceMessage,
    required this.messageIndex,
    required this.isStreaming,
    required this.isThinkingExpanded,
    required this.onToggleThinking,
    required this.onSavedToNotebook,
    required this.onSavedToMistakes,
  });

  /// 解析 <think>...</think> 块，返回 (thinkingContent, mainContent)
  static (String, String) _parseThinking(String content) {
    final thinkRegex = RegExp(
      r'<think>([\s\S]*?)</think>',
      caseSensitive: false,
    );
    final match = thinkRegex.firstMatch(content);
    if (match == null) return ('', content);
    final thinking = match.group(1)?.trim() ?? '';
    final main = content.replaceFirst(thinkRegex, '').trim();
    return (thinking, main);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (thinkingContent, mainContent) = _parseThinking(message.content);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.surface, cs.surface.withValues(alpha: 0.0)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // CoT 思维链折叠（有 thinking 内容时显示）
            if (thinkingContent.isNotEmpty) ...[
              CoTCollapsibleView(
                thinkingContent: thinkingContent,
                isExpanded: isThinkingExpanded,
                onToggle: onToggleThinking,
              ),
              const SizedBox(height: 8),
            ],

            // 主要内容（流式时用容错渲染）
            if (mainContent.isNotEmpty)
              MarkdownLatexView(
                data: mainContent,
                isStreaming: isStreaming,
                textStyle: TextStyle(
                  color: cs.onSurface,
                  height: 1.6,
                  fontSize: 15,
                ),
                codeBackgroundColor: cs.surfaceContainerHighest,
              )
            else if (isStreaming)
              // 流式接收中但内容为空时显示加载指示器
              SizedBox(
                width: 48,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(4),
                  color: cs.primary,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),

            // 图表渲染（来自 Python 计算引擎的 [CHART] 事件）
            if (message.chartBase64 != null) ...[
              const SizedBox(height: 12),
              _ChartWidget(chartBase64: message.chartBase64!),
            ],

            // 流式完成后显示操作栏
            if (!isStreaming && mainContent.isNotEmpty) ...[
              const SizedBox(height: 12),
              SolveResultActionBar(
                isSavedToNotebook: message.isSavedToNotebook,
                isSavedToMistakes: message.isSavedToMistakes,
                onSaveToNotebook: () => _saveToNotebook(context, ref),
                onSaveToMistakes: () => _saveToMistakes(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 收藏到笔记本
  Future<void> _saveToNotebook(BuildContext context, WidgetRef ref) async {
    final notebooks = await ref.read(notebookListProvider.future);
    if (!context.mounted) return;

    final active = notebooks.where((n) => !n.isArchived).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无笔记本，请先创建笔记本')));
      return;
    }

    // 弹出笔记本选择对话框
    final selectedNotebook = await showDialog<Notebook>(
      context: context,
      builder: (ctx) => _NotebookPickerDialog(notebooks: active),
    );

    if (selectedNotebook == null || !context.mounted) return;

    try {
      await NotebookService().createNotes([
        {
          'notebook_id': selectedNotebook.id,
          'role': 'assistant',
          'original_content': message.content,
          'title': '解题记录',
          'sources': {'type': 'solve', 'message_index': messageIndex},
        },
      ]);
      onSavedToNotebook();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }

  /// 加入错题本
  Future<void> _saveToMistakes(BuildContext context, WidgetRef ref) async {
    final subjects = await ref.read(subjectsProvider.future);
    if (!context.mounted) return;

    final options = await showDialog<_MistakeSaveOptions>(
      context: context,
      builder: (ctx) => _MistakeSaveDialog(
        subjects: subjects.where((s) => !s.isArchived).toList(),
      ),
    );

    if (options == null || !context.mounted) return;

    try {
      final sourceText = sourceMessage?.content.trim() ?? '';
      final hasSourceImages =
          (sourceMessage?.imageBase64List?.isNotEmpty ?? false);
      final questionText = sourceText.isNotEmpty
          ? sourceText
          : hasSourceImages
          ? '图片题（原图见解题历史）'
          : '解题助手记录';
      final mistakeContent = [
        '题目/追问：',
        questionText,
        '',
        '解题解析：',
        message.content,
      ].join('\n');

      await ReviewService().createMistakeFromPractice(
        subjectId: options.subjectId,
        title: '解题错题',
        content: mistakeContent,
        questionText: questionText,
        mistakeCategory: options.category,
      );
      onSavedToMistakes();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    }
  }
}

// ── 笔记本选择对话框 ──────────────────────────────────────────────────────────

class _NotebookPickerDialog extends StatefulWidget {
  final List<Notebook> notebooks;

  const _NotebookPickerDialog({required this.notebooks});

  @override
  State<_NotebookPickerDialog> createState() => _NotebookPickerDialogState();
}

class _NotebookPickerDialogState extends State<_NotebookPickerDialog> {
  Notebook? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.notebooks.isNotEmpty) {
      _selected = widget.notebooks.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择笔记本'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.notebooks.length,
          itemBuilder: (_, i) {
            final nb = widget.notebooks[i];
            return RadioListTile<Notebook>(
              title: Text(nb.name),
              value: nb,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              dense: true,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _MistakeSaveOptions {
  final int? subjectId;
  final String category;

  const _MistakeSaveOptions({required this.subjectId, required this.category});
}

class _MistakeSaveDialog extends StatefulWidget {
  final List<Subject> subjects;

  const _MistakeSaveDialog({required this.subjects});

  @override
  State<_MistakeSaveDialog> createState() => _MistakeSaveDialogState();
}

class _MistakeSaveDialogState extends State<_MistakeSaveDialog> {
  int? _subjectId;
  String _category = 'complete';

  static const _categories = [
    ('complete', '完全不会'),
    ('concept', '概念模糊'),
    ('calculation', '计算错误'),
    ('careless', '粗心'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.subjects.isNotEmpty) {
      _subjectId = widget.subjects.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('加入错题本'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            value: _subjectId,
            decoration: const InputDecoration(
              labelText: '关联科目',
              helperText: '选择科目后会创建复习卡',
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('暂不关联科目')),
              ...widget.subjects.map(
                (subject) => DropdownMenuItem<int?>(
                  value: subject.id,
                  child: Text(subject.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _subjectId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: '错因'),
            items: [
              for (final item in _categories)
                DropdownMenuItem(value: item.$1, child: Text(item.$2)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          if (widget.subjects.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '还没有科目，将先保存到错题本；创建科目后可再补关联。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _MistakeSaveOptions(subjectId: _subjectId, category: _category),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// ── 全屏图片查看器 ────────────────────────────────────────────────────────────

class _FullscreenImageViewer extends StatelessWidget {
  final List<String> base64Images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.base64Images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${initialIndex + 1} / ${base64Images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PhotoViewGallery.builder(
        itemCount: base64Images.length,
        pageController: PageController(initialPage: initialIndex),
        builder: (_, i) {
          final raw = base64Images[i];
          final data = raw.contains(',') ? raw.split(',').last : raw;
          return PhotoViewGalleryPageOptions(
            imageProvider: MemoryImage(base64Decode(data)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

// ── 图表渲染组件 ──────────────────────────────────────────────────────────────

/// 渲染 Python 计算引擎生成的图表（来自 [CHART] SSE 事件）
///
/// 支持点击全屏预览，解码失败时显示占位提示。
class _ChartWidget extends StatelessWidget {
  final String chartBase64;

  const _ChartWidget({required this.chartBase64});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 尝试解码 Base64 图表数据
    Uint8List? bytes;
    try {
      final data = chartBase64.contains(',')
          ? chartBase64.split(',').last
          : chartBase64;
      bytes = base64Decode(data);
    } catch (_) {
      bytes = null;
    }

    if (bytes == null) {
      // 解码失败时显示占位提示
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: cs.error, size: 20),
            const SizedBox(width: 8),
            Text('图表加载失败', style: TextStyle(color: cs.error, fontSize: 13)),
          ],
        ),
      );
    }

    // 解码成功，渲染图表并支持点击全屏预览
    return GestureDetector(
      onTap: () => _openFullscreen(context, bytes!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: cs.error, size: 20),
                const SizedBox(width: 8),
                Text('图表渲染失败', style: TextStyle(color: cs.error, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 全屏预览图表
  void _openFullscreen(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // 可缩放图表
            PhotoView(
              imageProvider: MemoryImage(bytes),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
            // 关闭按钮
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 空状态提示 ────────────────────────────────────────────────────────────────

class _EmptySolveHints extends StatelessWidget {
  final void Function(String hint) onTap;

  const _EmptySolveHints({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const hints = ['求解：f(x) = x² + 2x + 1，求极值', '证明：勾股定理', '计算：∫x²dx'];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_outlined, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              '拍照或输入题目，AI 按步骤解题',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '支持数学、物理、化学等多学科',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ...hints.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  onPressed: () => onTap(h),
                  child: Text(h, textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
