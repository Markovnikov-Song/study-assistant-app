import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../features/cas/cas_service.dart';
import '../../features/cas/cas_intent_detector.dart';
import '../../widgets/message_search_delegate.dart';
import '../../widgets/scene_card.dart';
import '../../widgets/session_history_sheet.dart';
import '../../widgets/markdown_latex_view.dart';
import '../../widgets/mcp_status_indicator.dart';
import '../../components/notebook/widgets/notebook_picker_sheet.dart';
import '../calendar/calendar_page.dart';
import '../../core/event_bus/app_event_bus.dart';
import '../../core/event_bus/calendar_events.dart';
import '../../tools/speech/speech_input_button.dart';
import '../spec/widgets/today_task_card.dart';
import '../../services/level2_monitor.dart';
import '../../providers/solve_prefill_provider.dart';
import '../../routes/app_router.dart';

// ─── ChatPage（参数化，支持通用/学科/任务三种场景）────────────

class ChatPage extends ConsumerStatefulWidget {
  final String? chatId;       // null = 通用对话（根路由 /）
  final int? subjectId;       // 学科专属对话
  final String? taskId;       // 任务对话
  final String? feynmanTopic; // 费曼学习模式：知识点主题

  const ChatPage({super.key, this.chatId, this.subjectId, this.taskId, this.feynmanTopic});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _useHybrid = false;
  bool _sending = false;
  final _intentDetector = CasIntentDetector(CasService());

  // chatKey: 'general' for general chat, subjectId string for subject chat, chatId for task chat
  String get _chatKey {
    if (widget.subjectId != null) return widget.subjectId!.toString();
    if (widget.chatId != null) return widget.chatId!;
    return 'general';
  }

  String get _sessionType {
    if (widget.feynmanTopic != null) return 'feynman';
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
          title: widget.feynmanTopic != null
              ? '费曼学习：${widget.feynmanTopic}'
              : widget.subjectId != null ? '学科对话' : '通用对话',
          updatedAt: DateTime.now(),
          subjectId: widget.subjectId?.toString(),
          taskId: widget.taskId,
        );

        // 费曼模式：自动注入引导消息
        if (widget.feynmanTopic != null) {
          final topic = widget.feynmanTopic!;
          final greeting = ChatMessage.local(
            role: MessageRole.assistant,
            content: '好，我们来用费曼学习法练习「$topic」。\n\n'
                '请用你自己的话，向我解释一下「$topic」是什么——就像在给一个完全不懂的人讲解一样。'
                '不用担心说错，说出你现在的理解就好。',
          );
          ref.read(chatProvider(_key).notifier).appendMessage(greeting);
        }
      }
    });
  }

  @override
  void deactivate() {
    // widget 离开树时清除回调，防止流式接收完成后调用已销毁的 setState
    ref.read(chatProvider(_key).notifier).detachCallbacks();
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

    // 记录用户活跃（供 Level 2 监控使用）
    Level2Monitor.recordActivity();

    // 清除末尾残留的空白 AI 气泡（上次请求失败或跳转后留下的）
    final msgs = ref.read(chatProvider(_key)).value;
    if (msgs != null && msgs.isNotEmpty &&
        msgs.last.role == MessageRole.assistant &&
        msgs.last.content.isEmpty &&
        msgs.last.type == MessageType.text) {
      ref.read(chatProvider(_key).notifier).deleteMessage(msgs.length - 1);
    }

    // 仅通用对话做 CAS 意图识别，navigate 类型直接跳转，不发给 AI
    if (widget.subjectId == null && widget.taskId == null) {
      final subjects = ref.read(subjectsProvider).valueOrNull;
      final intent = await _intentDetector.detect(text, subjects: subjects);
      if (!mounted) return;

      final actionId = intent.params['actionId'] as String?;
      final renderType = intent.params['render_type'] as String?;

      // navigate 类型：直接跳转，只在消息列表里显示用户消息，不调 AI
      if (actionId != null && renderType == 'navigate') {
        ref.read(chatProvider(_key).notifier).appendMessage(
          ChatMessage.local(role: MessageRole.user, content: text),
        );
        _handleCasIntent(intent, text);
        _scrollToBottom();
        return;
      }

      // 其他意图：正常发给 AI，然后处理意图
      _bindSendingCallback();
      await ref.read(chatProvider(_key).notifier).sendMessage(
        text,
        mode: SessionType.qa,
        useHybrid: _useHybrid,
        overrideSubjectId: _autoDetectedSubjectId,
      );
      _scrollToBottom();
      _handleIntentAfterSend(intent, text);
      return;
    }

    // 费曼学习模式：直接发给 AI，使用 feynman session type
    if (widget.feynmanTopic != null) {
      _bindSendingCallback();
      await ref.read(chatProvider(_key).notifier).sendMessage(
        text,
        mode: SessionType.feynman,
        overrideSubjectId: widget.subjectId,
      );
      _scrollToBottom();
      return;
    }

    // 学科/任务对话：直接发给 AI
    _bindSendingCallback();
    await ref.read(chatProvider(_key).notifier).sendMessage(
      text,
      mode: SessionType.qa,
      useHybrid: _useHybrid,
      overrideSubjectId: _autoDetectedSubjectId,
    );
    _scrollToBottom();
  }

  /// 发送给 AI 后处理意图（subject 静默归类 / SceneCard）
  void _handleIntentAfterSend(DetectedIntent intent, String userInput) {
    if (intent.type == IntentType.subject) {
      final subjectId = intent.params['subjectId'] as int?;
      final subjectName = intent.params['subjectName'] as String? ?? '';
      if (subjectId != null && subjectId != _autoDetectedSubjectId) {
        setState(() => _autoDetectedSubjectId = subjectId);
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
      return;
    }

    final actionId = intent.params['actionId'] as String?;
    if (actionId != null && intent.type != IntentType.none) {
      _handleCasIntent(intent, userInput);
      return;
    }

    if (intent.type != IntentType.subject && intent.type != IntentType.none) {
      final sceneCardData = _buildSceneCardData(intent);
      if (sceneCardData == null) return;
      ref.read(chatProvider(_key).notifier).appendMessage(
        ChatMessage.local(
          role: MessageRole.assistant,
          content: '',
          type: MessageType.sceneCard,
          sceneCardData: sceneCardData,
        ),
      );
    }
  }

  /// CAS render_type 处理：navigate / card / modal / text / param_fill
  void _handleCasIntent(DetectedIntent intent, String originalText) {
    final renderType = intent.params['render_type'] as String? ?? 'text';
    final route = intent.params['route'] as String?;
    final text = intent.params['text'] as String?;
    final actionId = intent.params['actionId'] as String?;

    switch (renderType) {
      case 'navigate':
        if (route != null) {
          // 先插入确认气泡，再跳转（气泡留在对话流里）
          final confirmText = _navigateConfirmText(actionId, route);
          ref.read(chatProvider(_key).notifier).appendMessage(
            ChatMessage.local(role: MessageRole.assistant, content: confirmText),
          );
          // 短暂延迟让气泡渲染后再跳转，避免页面切换时气泡闪烁
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) context.push(route);
          });
        }
      case 'text':
        if (text != null && text.isNotEmpty) {
          ref.read(chatProvider(_key).notifier).appendMessage(
            ChatMessage.local(role: MessageRole.assistant, content: text),
          );
        }
      case 'card':
        // 结构化卡片：将 card 数据转为 Markdown 文本气泡展示
        _handleCasCard(intent.params);
      case 'modal':
        if (text != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(text),
            ),
          );
        }
      case 'param_fill':
        // 缺参时插入引导文字，再跳转到对应工具页
        if (actionId != null) {
          final guideText = _paramFillGuideText(actionId);
          ref.read(chatProvider(_key).notifier).appendMessage(
            ChatMessage.local(role: MessageRole.assistant, content: guideText),
          );
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) _handleParamFillFallback(actionId);
          });
        }
      default:
        break;
    }
  }

  /// navigate 跳转后的确认气泡文案（Markdown 链接格式）
  String _navigateConfirmText(String? actionId, String route) {
    switch (actionId) {
      case 'open_calendar':
        return '已为您打开 [学习日历]($route) ✓';
      case 'open_notebook':
        return '已为您打开 [笔记本]($route) ✓';
      case 'open_course_space':
        return '已为您打开 [课程空间]($route) ✓';
      case 'make_quiz':
        return '已为您跳转到 [出题页面]($route) ✓';
      case 'recommend_mistake_practice':
        return '已为您打开 [复盘中心]($route) ✓';
      case 'start_feynman':
        // 从路由参数里取 topic
        final uri = Uri.tryParse(route);
        final topic = uri?.queryParameters['topic'] ?? '知识点';
        return '好的，我们来用费曼学习法练习「$topic」，正在为你开启对话…';
      default:
        // 通用兜底：从路由推断名称
        final name = _routeDisplayName(route);
        return '已为您打开 [$name]($route) ✓';
    }
  }

  /// param_fill 引导文字
  String _paramFillGuideText(String actionId) {
    switch (actionId) {
      case 'make_quiz':
        return '好的，带你去出题页面，可以在那里选择学科和题型 →';
      case 'make_plan':
        return '好的，带你去规划页面，可以在那里制定学习计划 →';
      case 'add_calendar_event':
        return '好的，带你去日历，可以在那里添加学习事件 →';
      case 'recommend_mistake_practice':
        return '好的，带你去复盘中心，可以在那里选择要练习的错题 →';
      default:
        return '好的，带你去对应页面完成操作 →';
    }
  }

  /// 从路由路径推断显示名称
  String _routeDisplayName(String route) {
    if (route.contains('calendar')) return '学习日历';
    if (route.contains('notebook')) return '笔记本';
    if (route.contains('course-space')) return '课程空间';
    if (route.contains('quiz')) return '出题';
    if (route.contains('mistake') || route.contains('review')) return '复盘中心';
    if (route.contains('solve')) return '解题';
    if (route.contains('spec')) return '学习规划';
    return '目标页面';
  }

  /// 参数补全兜底：跳转到对应工具页让用户手动操作
  void _handleParamFillFallback(String actionId) {
    final routeMap = {
      'make_quiz': '/toolkit/quiz',
      'make_plan': '/spec',
      'open_calendar': '/toolkit/calendar',
      'add_calendar_event': '/toolkit/calendar',
      'recommend_mistake_practice': '/toolkit/mistake-book',
      'open_notebook': '/toolkit/notebooks',
      'solve_problem': '/toolkit/solve',
    };
    final route = routeMap[actionId];
    if (route != null) context.push(route);
  }

  /// CAS card 类型：将结构化卡片数据转为 Markdown 气泡 + 跳转链接
  void _handleCasCard(Map<String, dynamic> params) {
    final cardType = params['card_type'] as String? ?? '';
    final title = params['title'] as String? ?? '';
    final actionRoute = params['action_route'] as String?;

    final buf = StringBuffer();
    if (title.isNotEmpty) buf.writeln('**$title**\n');

    switch (cardType) {
      case 'mistake_list':
        final items = params['items'] as List? ?? [];
        for (int i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemTitle = item['title'] as String? ?? '错题 ${i + 1}';
          final category = item['category'] as String? ?? '';
          buf.writeln('${i + 1}. $itemTitle${category.isNotEmpty ? '（$category）' : ''}');
        }
        if (actionRoute != null) {
          buf.writeln('\n[→ 前往复盘中心]($actionRoute)');
        }
      default:
        // 通用卡片：直接显示 title + 跳转链接
        if (actionRoute != null) {
          final name = _routeDisplayName(actionRoute);
          buf.writeln('[→ 前往$name]($actionRoute)');
        }
    }

    final content = buf.toString().trim();
    if (content.isNotEmpty) {
      ref.read(chatProvider(_key).notifier).appendMessage(
        ChatMessage.local(role: MessageRole.assistant, content: content),
      );
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
        final toolName = intent.params['toolName'] as String? ?? '工具';
        return SceneCardData(
          sceneType: SceneType.tool,
          title: '跳转到$toolName？',
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
      case IntentType.calendar:
        return SceneCardData(
          sceneType: SceneType.calendar,
          title: '检测到日程需求',
          subtitle: intent.params['date'] != null
              ? '添加到日历？'
              : '添加到学习日历？',
          confirmLabel: '添加到日历',
          dismissLabel: '稍后再说',
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

    // 显示 loading
    if (mounted) setState(() => _sending = true);

    try {
      final b64 = base64Encode(await file.readAsBytes());
      if (!mounted) return;
      final text = await ref.read(chatProvider(_key).notifier).recognizeOcr(b64);
      if (!mounted) return;

      if (text == null || text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('识别失败，请确保图片清晰且包含文字')),
        );
        return;
      }

      // 学科对话：跳转到解题页面并预填文字
      if (widget.subjectId != null) {
        // 先在当前对话里插入一条用户图片消息（让用户看到反馈）
        ref.read(chatProvider(_key).notifier).appendMessage(
          ChatMessage.local(role: MessageRole.user, content: '📷 图片识别：$text'),
        );
        _scrollToBottom();
        // 跳转到解题页，并把识别文字预填到输入框
        if (mounted) {
          context.push(AppRoutes.toolkitSolve);
          // 短暂延迟等页面挂载后再填充
          await Future.delayed(const Duration(milliseconds: 300));
          // SolvePage 有自己的输入框，通过全局 provider 传递预填文字
          ref.read(solvePreFillProvider.notifier).state = text;
        }
        return;
      }

      // 通用对话：直接填入输入框并发送
      _inputCtrl.text = text;
      await _submit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别出错：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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

    PreferredSizeWidget? appBar;
    if (multiSelect.isActive) {
      appBar = AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => ref.read(multiSelectProvider.notifier).cancel(),
        ),
        title: Text('已选中 $selectedCount 条消息'),
        centerTitle: false,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // 多选模式用普通 AppBar
      appBar: appBar,
      body: multiSelect.isActive
          ? _ChatBody(
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
            )
          : _ChatPageWithSliverAppBar(
              chatKey: _chatKey,
              sessionType: _sessionType,
              subjectId: widget.subjectId,
              taskId: widget.taskId,
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
    );
  }
}

// ─── 带 SliverAppBar 的答疑室内容 ────────────────────────────────

class _ChatPageWithSliverAppBar extends ConsumerWidget {
  final String chatKey;
  final String sessionType;
  final int? subjectId;
  final String? taskId;
  final bool useHybrid, sending;
  final TextEditingController inputCtrl;
  final ScrollController scrollCtrl;
  final ValueChanged<bool> onHybridChanged;
  final VoidCallback onSubmit, onCancel, onCamera, onGallery;

  const _ChatPageWithSliverAppBar({
    required this.chatKey,
    required this.sessionType,
    required this.subjectId,
    required this.taskId,
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
    // 动态获取标题
    String title = '助教';
    if (subjectId != null) {
      final subjectsAsync = ref.watch(subjectsProvider);
      title = subjectsAsync.valueOrNull
              ?.firstWhere(
                (s) => s.id == subjectId,
                orElse: () => Subject(id: 0, name: '学科对话', createdAt: DateTime.now()),
              )
              .name ??
          '学科对话';
    } else if (taskId != null) {
      title = taskId!;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        automaticallyImplyLeading: subjectId != null || taskId != null,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: subjectId == null && taskId == null
            ? [const McpStatusIndicator(), const SizedBox(width: 8)]
            : null,
      ),
      body: _ChatBody(
        chatKey: chatKey,
        sessionType: sessionType,
        subjectId: subjectId ?? 0,
        isGeneral: subjectId == null && taskId == null,
        useHybrid: useHybrid,
        sending: sending,
        inputCtrl: inputCtrl,
        scrollCtrl: scrollCtrl,
        onHybridChanged: onHybridChanged,
        onSubmit: onSubmit,
        onCancel: onCancel,
        onCamera: onCamera,
        onGallery: onGallery,
      ),
    );
  }
}

// ─── _ChatBody ────────────────────────────────────────────────

class _ChatBody extends ConsumerStatefulWidget {
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
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  // 用户是否主动上翻（上翻后停止自动跟随）
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    widget.scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollCtrl.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollCtrl.hasClients) return;
    final pos = widget.scrollCtrl.position;
    // 距离底部超过 80px 认为用户主动上翻
    final atBottom = pos.pixels >= pos.maxScrollExtent - 80;
    if (_userScrolledUp == atBottom) {
      setState(() => _userScrolledUp = !atBottom);
    }
  }

  /// 流式期间每次消息更新后调用，若用户没有上翻则跟随滚到底部
  void _maybeScrollToBottom() {
    if (_userScrolledUp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = widget.scrollCtrl;
      if (!ctrl.hasClients) return;
      ctrl.jumpTo(ctrl.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.chatKey, widget.sessionType);
    final chatState = ref.watch(chatProvider(key));
    final multiSelect = ref.watch(multiSelectProvider);

    // 每次消息列表更新时，若用户没有上翻则跟随滚底
    if (widget.sending) {
      _maybeScrollToBottom();
    } else {
      // 流式结束后重置上翻标记，允许下次发送时重新跟随
      _userScrolledUp = false;
    }

    return Column(
      children: [
        _SessionBar(chatKey: widget.chatKey, sessionType: widget.sessionType, subjectId: widget.subjectId),
        Expanded(
          child: chatState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            data: (msgs) => msgs.isEmpty
                ? SingleChildScrollView(
                    child: _EmptyHints(subjectId: widget.subjectId, onTap: (h) => widget.inputCtrl.text = h),
                  )
                : ListView.builder(
                    controller: widget.scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: msgs.length + (widget.sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (widget.sending && i == msgs.length) {
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
                      // 流式期间最后一条 AI 消息用纯文本渲染，避免 Markdown 解析导致高度突变
                      final isStreamingLastMsg = widget.sending &&
                          !msg.isUser &&
                          i == msgs.length - 1;
                      return _Bubble(
                        // 用 forceRawText 状态作为 key 的一部分，确保流式结束后强制重建触发完整渲染
                        key: ValueKey('bubble_${msg.id}_$isStreamingLastMsg'),
                        message: msg,
                        forceRawText: isStreamingLastMsg,
                        onDelete: multiSelect.isActive
                            ? null
                            : () => ref.read(chatProvider(key).notifier).deleteMessage(i),
                      );
                    },
                  ),
          ),
        ),
        if (!multiSelect.isActive) ...[
          // 通用对话不显示「结合通用知识」checkbox（没有知识库）
          if (!widget.isGeneral)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Row(
                children: [
                  Checkbox(
                    value: widget.useHybrid,
                    onChanged: (v) => widget.onHybridChanged(v ?? false),
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
          SafeArea(
            top: false,
            child: _InputBar(
              controller: widget.inputCtrl,
              sending: widget.sending,
              placeholder: '输入问题…',
              onSubmit: widget.onSubmit,
              onCancel: widget.onCancel,
              onCamera: widget.onCamera,
              onGallery: widget.onGallery,
            ),
          ),
        ] else
          SafeArea(
            top: false,
            child: _MultiSelectBar(
              subjectId: widget.subjectId,
              messages: chatState.maybeWhen(data: (msgs) => msgs, orElse: () => []),
            ),
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
      context.push('/spec');
    case SceneType.tool:
      final route = data.payload['toolRoute'] as String?;
      if (route != null) context.push(route);
    case SceneType.spec:
      context.push('/spec');
    case SceneType.calendar:
      final payload = data.payload;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CalendarPage(
          renderMode: 'modal',
          sceneSource: 'agent',
          prefillDate: payload['date'] as DateTime?,
          prefillTime: payload['time'] as String?,
          onResult: (result) {
            if (result.success) {
              final eventId = result.data['eventId'] as int?;
              final eventDate = result.data['eventDate'] as DateTime?;
              ref.read(chatProvider(key).notifier).appendMessage(
                ChatMessage.local(
                  role: MessageRole.assistant,
                  content: '已添加到日历 ✓ [查看日历](/toolkit/calendar)',
                ),
              );
              if (eventId != null && eventDate != null) {
                AppEventBus.instance.fire(CalendarEventCreated(
                  eventId: eventId,
                  eventDate: eventDate,
                  source: 'agent',
                ));
              }
            }
          },
        ),
      );
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
  /// 流式期间传 true，用纯文本渲染避免 Markdown 解析导致高度突变
  final bool forceRawText;
  const _Bubble({super.key, required this.message, this.onDelete, this.forceRawText = false});

  void _onLongPress(BuildContext context, WidgetRef ref) {
    final multiSelect = ref.read(multiSelectProvider);
    if (multiSelect.isActive) {
      ref.read(multiSelectProvider.notifier).toggle(message.id);
      return;
    }
    // 弹出操作菜单：复制 / 进入多选
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('多选'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(multiSelectProvider.notifier).activate(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final multiSelect = ref.watch(multiSelectProvider);
    final isSelected = multiSelect.selectedMessageIds.contains(message.id);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _onLongPress(context, ref),
        onTap: () {
          if (multiSelect.isActive) ref.read(multiSelectProvider.notifier).toggle(message.id);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            gradient: isUser
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
                    ],
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 18),
            ),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isUser
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
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
                  ? Text(
                      message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.5,
                        fontSize: 15,
                      ),
                    )
                  : forceRawText
                      ? Text(
                          message.content,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.6,
                            fontSize: 15,
                          ),
                        )
                      : MarkdownLatexView(
                          data: message.content,
                          textStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.6,
                            fontSize: 15,
                          ),
                          codeBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    final List<String> hints;
    if (subjectId == 0) {
      // 通用对话默认提示（不依赖知识库）
      hints = const ['今天学了什么？', '帮我解释一个概念', '我想制定学习计划'];
    } else {
      final hintsAsync = ref.watch(hintProvider((subjectId, true)));
      hints = hintsAsync.valueOrNull ??
          const ['这道题的解题思路是什么？', '帮我总结这章的重点', '这个概念怎么理解？'];
    }
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 今日任务卡片（仅通用对话显示）
            if (subjectId == 0) ...[
              const TodayTaskCard(),
            ],
            // 装饰图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cs.primaryContainer.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 48,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '试试这些问题',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...hints.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outline,
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
                          color: cs.onSurface,
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outline.withValues(alpha: 0.5),
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
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.camera_alt_outlined,
                color: cs.onSurfaceVariant,
              ),
              onPressed: sending ? null : onCamera,
              tooltip: '拍照识题',
            ),
          ),
          const SizedBox(width: 8),
          // 图库按钮
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.image_outlined,
                color: cs.onSurfaceVariant,
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
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cs.outline,
                ),
              ),
              child: TextField(
                controller: controller,
                maxLines: 5,
                minLines: 1,
                enabled: !sending,
                style: TextStyle(
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 语音输入按钮
          SpeechInputButton(
            onResult: (text) {
              controller.text = '${controller.text}$text';
            },
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          // 发送按钮
          Container(
            decoration: BoxDecoration(
              gradient: sending
                  ? null
                  : LinearGradient(
                      colors: [cs.primary, cs.secondary],
                    ),
              color: sending ? Colors.red.shade400 : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: sending
                  ? null
                  : [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
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
