// ─────────────────────────────────────────────────────────────
// chat_provider.dart — 聊天状态管理
//
// 【Riverpod 核心概念】
// Provider 是"状态容器"，类似 Python 里的全局变量，但：
//   1. 有类型安全
//   2. 状态变化时自动通知 UI 重建
//   3. 按需创建和销毁，不会内存泄漏
//
// 三种常用 Provider：
//   Provider<T>         — 只读，提供一个不变的值（如 Service 实例）
//   StateProvider<T>    — 可读写的简单状态（如 bool、int）
//   StateNotifierProvider<Notifier, State> — 复杂状态，逻辑封装在 Notifier 类里
// ─────────────────────────────────────────────────────────────

import 'dart:async'; // Dart 异步库
import 'package:dio/dio.dart'; // HTTP 库（用到 CancelToken、DioException）
import 'package:flutter/foundation.dart'; // VoidCallback
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 状态管理
import '../models/chat_message.dart';
import '../providers/history_provider.dart';
import '../services/chat_service.dart';
import '../services/background_task_service.dart';

// ─── Provider 1：ChatService 实例 ────────────────────────────
// Provider<ChatService>：提供一个 ChatService 实例
// (ref) => ChatService()：工厂函数，第一次用到时才创建
// 类比 Python：chat_service = ChatService()  # 全局单例
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// ─── Provider 2：消息列表状态 ─────────────────────────────────
// StateNotifierProviderFamily：带参数的 StateNotifierProvider
// "Family" 表示"一族"，同一个 Provider 可以用不同参数创建多个独立实例
//
// 类型参数解释：
//   ChatNotifier                    — 管理状态的 Notifier 类
//   AsyncValue<List<ChatMessage>>   — 状态类型（异步的消息列表）
//   (String, String)                — 参数类型（chatKey, 会话类型名）
//
// AsyncValue<T> 是 Riverpod 的异步状态包装器，有三种状态：
//   AsyncValue.loading()    — 加载中
//   AsyncValue.data(value)  — 有数据
//   AsyncValue.error(e, st) — 出错了
//
// key.$1 是 chatKey（字符串），通用对话为 'general'，学科对话为 subjectId 字符串
// key.$2 是会话类型名（如 'qa', 'solve'）
// 类比 Python：key[0]
final chatProvider = StateNotifierProviderFamily<ChatNotifier, AsyncValue<List<ChatMessage>>, (String, String)>(
  (ref, key) {
    ref.keepAlive(); // 防止切换 Tab 时被 dispose
    final subjectId = int.tryParse(key.$1) ?? 0;
    return ChatNotifier(
      ref.watch(chatServiceProvider),
      chatKey: key.$1,
      subjectId: subjectId,
      // 新会话创建后刷新历史列表：
    // - sessionsProvider(subjectId)：助教页左上角历史记录
    // - allSessionsProvider：「我的」历史记录页
      onSessionCreated: () {
        ref.invalidate(sessionsProvider(subjectId));
        ref.invalidate(allSessionsProvider);
      },
    );
  },
);

// ─── Provider 3：发送中状态 ───────────────────────────────────
// StateProviderFamily<bool, (String, String)>：
//   每个 (chatKey, type) 组合有独立的 bool 状态
// (ref, _) => false：初始值是 false（没在发送）
// _ 表示参数不用（Dart 惯例，类似 Python 的 _）
final chatSendingProvider = StateProviderFamily<bool, (String, String)>((ref, _) => false);

// ─── Provider 4：会话列表 ─────────────────────────────────────
// FutureProviderFamily：异步加载数据的 Provider
// 每次 subjectId 不同，就有独立的会话列表缓存
final sessionsProvider = FutureProviderFamily<List<ConversationSession>, int>(
  (ref, subjectId) => ref.watch(chatServiceProvider).getSessions(subjectId),
);

// ─── 自定义异常：用户取消请求 ─────────────────────────────────
// implements Exception：实现 Exception 接口，让这个类可以被 throw/catch
class DioCancel implements Exception {}

// ─── ChatNotifier：聊天状态管理器 ────────────────────────────
// StateNotifier<T>：持有状态 T，提供修改状态的方法
// 类比 Python：一个类，有属性 state，修改 state 时自动通知订阅者
//
// 继承语法：class A extends B — A 继承 B，类似 Python 的 class A(B)
// super(...)：调用父类构造函数，类似 Python 的 super().__init__(...)
class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatService _service;  // HTTP 服务，用于发请求
  final String _chatKey;       // 对话 key：通用对话为 'general'，学科对话为 subjectId 字符串
  final int _subjectId;        // 学科 ID（从 chatKey 解析，通用对话时为 0）
  int? _currentSessionId;      // 当前会话 ID，null 表示还没开始对话
  CancelToken? _cancelToken;   // Dio 的取消令牌，null 表示没有进行中的请求

  // 回调函数：发送状态变化时通知外部（UI 层注册这个回调来更新按钮状态）
  void Function(bool)? onSendingChanged;

  // 新会话创建后的回调（由 chatProvider 注入，用于刷新历史列表）
  final VoidCallback? onSessionCreated;

  // 清除回调（widget dispose 时调用，防止悬空引用）
  void detachCallbacks() {
    onSendingChanged = null;
  }

  // 构造函数
  ChatNotifier(this._service, {required String chatKey, required int subjectId, this.onSessionCreated})
      : _chatKey = chatKey,
        _subjectId = subjectId,
        super(const AsyncValue.data([]));

  int? get currentSessionId => _currentSessionId;
  String get chatKey => _chatKey;

  // ─── 发送消息（流式打字机效果）──────────────────────────
  Future<void> sendMessage(
    String text, {
    required SessionType mode,
    bool useBroad = false,
    bool useHybrid = false,
    int? overrideSubjectId, // 通用对话自动归类时传入
  }) async {
    if (_cancelToken != null) return;

    final current = List<ChatMessage>.from(state.value ?? []);
    final userMsg = ChatMessage.local(role: MessageRole.user, content: text);
    _cancelToken = CancelToken();
    onSendingChanged?.call(true);

    // 乐观更新：用户消息 + AI 占位消息
    final placeholder = ChatMessage.local(role: MessageRole.assistant, content: '');
    state = AsyncValue.data([...current, userMsg, placeholder]);

    final buffer = StringBuffer();
    StreamSubscription<String>? sub;
    bool cancelled = false;

    // 启动后台任务保活，防止切换应用时中断 AI 输出
    await BackgroundTaskService.instance.startTask(BackgroundTaskType.aiStreaming);

    try {
      final stream = _service.sendMessageStream(
        text,
        subjectId: overrideSubjectId ?? _subjectId,
        sessionId: _currentSessionId,
        mode: mode,
        useHybrid: useHybrid || useBroad,
      );

      final completer = Completer<void>();

      sub = stream.listen(
        (event) {
          // 过滤空数据帧（用于快速建立连接的心跳）
          if (event.isEmpty) return;
          
          if (event == '[DONE]') {
            if (!completer.isCompleted) completer.complete();
            return;
          }
          if (event == '[NEEDS_CONFIRMATION]') {
            final hint = ChatMessage.local(
              role: MessageRole.assistant,
              content: '在已上传资料中未找到相关内容。\n\n可以勾选「结合通用知识」后重新提问，AI 将优先检索知识库，检索不到时自动用通用知识回答。',
            );
            // 保留用户消息，只替换 AI 占位消息为提示消息
            state = AsyncValue.data([...current, userMsg, hint]);
            if (!completer.isCompleted) completer.complete();
            return;
          }
          if (event.startsWith('[SESSION_ID:')) {
            // 后端通过 SSE 返回本次会话 ID，更新后续消息复用同一会话
            final idStr = event.substring(12, event.length - 1);
            final id = int.tryParse(idStr);
            if (id != null) {
              final isNewSession = _currentSessionId == null;
              _currentSessionId = id;
              // 新会话第一次创建时刷新历史列表
              if (isNewSession) onSessionCreated?.call();
            }
            return;
          }
          if (event.startsWith('[SOURCES]')) return; // 后端已保存，忽略
          if (event.startsWith('[ERROR]')) {
            if (!completer.isCompleted) {
              completer.completeError(Exception(event.substring(7)));
            }
            return;
          }

          // 普通 token：追加并更新最后一条 AI 消息（直接替换末尾，不重建整个列表）
          buffer.write(event);
          final msgs = state.value;
          if (msgs != null && msgs.isNotEmpty && msgs.last.role == MessageRole.assistant) {
            final updated = ChatMessage.local(
              role: MessageRole.assistant,
              content: buffer.toString(),
            );
            state = AsyncValue.data([...msgs.sublist(0, msgs.length - 1), updated]);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      // 支持取消
      _cancelToken!.whenCancel.then((_) {
        cancelled = true;
        sub?.cancel();
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;

    } catch (e, st) {
      if (buffer.isEmpty) {
        // 出错时保留用户消息，显示友好的错误消息
        final errorMessage = _formatErrorMessage(e);
        final errorMsg = ChatMessage.local(
          role: MessageRole.assistant,
          content: errorMessage,
          type: MessageType.error,
        );
        state = AsyncValue.data([...current, userMsg, errorMsg]);
      } else {
        // 有部分内容时保留已输出内容，追加错误提示
        final errorMessage = _formatErrorMessage(e);
        final msgs = state.value;
        if (msgs != null && msgs.isNotEmpty && msgs.last.role == MessageRole.assistant) {
          final updated = ChatMessage.local(
            role: MessageRole.assistant,
            content: '${msgs.last.content}\n\n⚠️ $errorMessage',
          );
          state = AsyncValue.data([...msgs.sublist(0, msgs.length - 1), updated]);
        }
      }
    } finally {
      sub?.cancel();
      _cancelToken = null;
      onSendingChanged?.call(false);
      
      // 结束后台任务保活
      await BackgroundTaskService.instance.endTask(BackgroundTaskType.aiStreaming);

      // 取消时：保留用户消息，移除空的 AI 占位消息
      if (cancelled && buffer.isEmpty) {
        state = AsyncValue.data([...current, userMsg]);
        return;
      }

      // AI 回复为空（如 422 错误、CAS 跳转后无回复）：移除空的 AI 占位消息
      if (!cancelled && buffer.isEmpty) {
        final msgs = state.value;
        if (msgs != null && msgs.isNotEmpty && msgs.last.role == MessageRole.assistant && msgs.last.content.isEmpty) {
          state = AsyncValue.data(msgs.sublist(0, msgs.length - 1));
        }
      }
    }
  }

  // ─── 取消正在发送的请求 ────────────────────────────────────
  void cancelSending() {
    // ?. 空安全调用：_cancelToken 不为 null 时才调用 cancel()
    _cancelToken?.cancel('用户取消');
    // cancel() 会让 Dio 抛出 DioExceptionType.cancel，上面的 catch 会处理
  }

  // ─── 生成思维导图 ──────────────────────────────────────────
  Future<void> generateMindMap({int? docId}) async {
    // 设置加载状态（UI 显示 loading）
    state = const AsyncValue.loading();
    try {
      final content = await _service.generateMindMap(
        _subjectId,
        sessionId: _currentSessionId,
        docId: docId,
      );
      // 思维导图内容用一条 assistant 消息存储（Markdown 格式）
      final msg = ChatMessage.local(role: MessageRole.assistant, content: content);
      state = AsyncValue.data([msg]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ─── OCR 图片识别 ──────────────────────────────────────────
  // 返回 String?：识别成功返回文字，失败抛出异常（由调用方处理提示）
  Future<String?> recognizeOcr(String imageBase64) async {
    final result = await _service.recognizeImage(imageBase64);
    return result.text.isEmpty ? null : result.text;
  }

  // ─── 加载历史会话 ──────────────────────────────────────────
  Future<void> loadSession(int sessionId) async {
    state = const AsyncValue.loading();
    try {
      final messages = await _service.getSessionHistory(sessionId);
      _currentSessionId = sessionId; // 切换到这个会话
      state = AsyncValue.data(messages);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ─── 删除某条消息（仅本地，不调用 API）────────────────────
  void deleteMessage(int index) {
    // 复制当前列表（不能直接修改，Dart 的不可变状态原则）
    final msgs = List<ChatMessage>.from(state.value ?? []);
    // 边界检查，防止越界
    if (index >= 0 && index < msgs.length) {
      msgs.removeAt(index); // 删除指定位置的元素，类似 Python 的 list.pop(index)
      state = AsyncValue.data(msgs);
    }
  }

  // ─── 新建对话（清空当前消息，重置会话 ID）─────────────────
  void newSession() {
    _currentSessionId = null;           // 下次发消息时服务器会创建新会话
    state = const AsyncValue.data([]); // 清空消息列表
  }

  // ─── 追加一条本地消息（用于 SceneCard 等本地状态）─────────
  void appendMessage(ChatMessage message) {
    final current = state.value ?? [];
    state = AsyncValue.data([...current, message]);
  }

  // ─── 刷新状态（触发 UI 重建，用于本地字段变更后同步）──────
  void refreshState() {
    final current = state.value ?? [];
    state = AsyncValue.data(List.from(current));
  }

  // ─── 格式化错误消息，提供友好的用户提示 ───────────────────
  String _formatErrorMessage(Object e) {
    final errorStr = e.toString();
    
    // 检查是否是已知的错误类型
    if (errorStr.contains("API 配置错误") || errorStr.contains("API Key")) {
      return "API 配置错误\n\n请进入「我的」→「AI 模型配置」检查您的 API 配置。";
    }
    
    if (errorStr.contains("余额不足") || errorStr.contains("insufficient")) {
      return "账户余额不足\n\n请检查您的 API 账户余额或切换其他配置。";
    }
    
    if (errorStr.contains("请求过于频繁") || errorStr.contains("RateLimit")) {
      return "请求过于频繁\n\n请稍等片刻再试。";
    }
    
    if (errorStr.contains("网络") || errorStr.contains("连接") || errorStr.contains("timeout")) {
      return "网络连接异常\n\n请检查网络连接后重试。";
    }
    
    if (errorStr.contains("AI 服务")) {
      return "AI 服务暂时不可用\n\n请稍后重试。";
    }
    
    // 其他未知错误，提供通用提示
    return "服务暂时不可用\n\n请稍后重试或联系客服。";
  }
}
