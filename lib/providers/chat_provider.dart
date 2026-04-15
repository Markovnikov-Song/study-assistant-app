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
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 状态管理
import '../models/chat_message.dart';
import '../services/chat_service.dart';

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
//   (int, String)                   — 参数类型（学科ID, 会话类型名）
//
// AsyncValue<T> 是 Riverpod 的异步状态包装器，有三种状态：
//   AsyncValue.loading()    — 加载中
//   AsyncValue.data(value)  — 有数据
//   AsyncValue.error(e, st) — 出错了
//
// key.$1 是取元组第一个元素（subjectId），$2 是第二个（类型名）
// 类比 Python：key[0]
final chatProvider = StateNotifierProviderFamily<ChatNotifier, AsyncValue<List<ChatMessage>>, (int, String)>(
  (ref, key) => ChatNotifier(ref.watch(chatServiceProvider), key.$1),
  // ref.watch(chatServiceProvider)：获取 ChatService 实例，并订阅它的变化
);

// ─── Provider 3：发送中状态 ───────────────────────────────────
// StateProviderFamily<bool, (int, String)>：
//   每个 (subjectId, type) 组合有独立的 bool 状态
// (ref, _) => false：初始值是 false（没在发送）
// _ 表示参数不用（Dart 惯例，类似 Python 的 _）
final chatSendingProvider = StateProviderFamily<bool, (int, String)>((ref, _) => false);

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
  final int _subjectId;        // 这个 Notifier 对应哪个学科
  int? _currentSessionId;      // 当前会话 ID，null 表示还没开始对话
  CancelToken? _cancelToken;   // Dio 的取消令牌，null 表示没有进行中的请求

  // 回调函数：发送状态变化时通知外部（UI 层注册这个回调来更新按钮状态）
  // void Function(bool)?：类型是"接受一个 bool 参数、无返回值的函数"，可为 null
  // 类比 Python：on_sending_changed: Optional[Callable[[bool], None]] = None
  void Function(bool)? onSendingChanged;

  // 构造函数
  // : super(const AsyncValue.data([]))：初始状态是"有数据，数据是空列表"
  ChatNotifier(this._service, this._subjectId) : super(const AsyncValue.data([]));

  // getter：暴露当前会话 ID（只读）
  int? get currentSessionId => _currentSessionId;

  // ─── 发送消息 ──────────────────────────────────────────────
  Future<void> sendMessage(
    String text, {
    required SessionType mode,
    bool useBroad = false,
    bool useHybrid = false,
  }) async {
    // 如果已有进行中的请求（_cancelToken 不为 null），直接返回，防止重复发送
    if (_cancelToken != null) return;

    // 保存当前消息列表的快照，出错时用于回滚
    // List<ChatMessage>.from(...)：复制一个新列表，避免引用同一个对象
    // state.value：取出 AsyncValue 里的实际数据（List<ChatMessage>）
    // ?? []：如果 state.value 是 null，用空列表代替
    final current = List<ChatMessage>.from(state.value ?? []);

    // 创建用户消息（本地临时对象，还没有服务器 ID）
    final userMsg = ChatMessage.local(role: MessageRole.user, content: text);

    // 创建取消令牌（用于后续取消这个 HTTP 请求）
    _cancelToken = CancelToken();

    // 通知 UI 进入"发送中"状态（按钮变红色停止图标）
    // ?.call(true)：如果 onSendingChanged 不为 null，就调用它
    // 类比 Python：if self.on_sending_changed: self.on_sending_changed(True)
    onSendingChanged?.call(true);

    // 乐观更新：立刻把用户消息加入列表显示，不等服务器响应
    // ...current：展开运算符，类似 Python 的 *current
    // 相当于 [...current, userMsg] == current + [userMsg]
    state = AsyncValue.data([...current, userMsg]);

    try {
      // 发送 HTTP 请求，等待 AI 回复
      final result = await _service.sendMessage(
        text,
        subjectId: _subjectId,
        sessionId: _currentSessionId,
        mode: mode,
        useBroad: useBroad,
        useHybrid: useHybrid,
        cancelToken: _cancelToken,
      );

      // 保存服务器分配的会话 ID（下次发消息时带上，保持对话连续性）
      _currentSessionId = result.sessionId;

      // strict 模式找不到相关资料时，后端返回 needsConfirmation=true
      if (result.needsConfirmation) {
        // 显示提示消息，引导用户勾选"结合通用知识"
        final hint = ChatMessage.local(
          role: MessageRole.assistant,
          content: '在已上传资料中未找到相关内容。\n\n可以勾选「结合通用知识」后重新提问，AI 将优先检索知识库，检索不到时自动用通用知识回答。',
        );
        // state.value! 的 ! 表示"我确定这不是 null"（强制非空断言）
        state = AsyncValue.data([...state.value!, hint]);
        return; // 提前退出，不执行后面的正常流程
      }

      // 正常情况：把 AI 回复加入消息列表
      state = AsyncValue.data([...state.value!, result.message]);

    } on DioException catch (e) {
      // 捕获 Dio 的 HTTP 异常
      if (e.type == DioExceptionType.cancel) {
        // 用户主动点了停止按钮，回滚到发送前的状态（移除乐观更新的用户消息）
        state = AsyncValue.data(current);
      } else {
        // 其他网络错误：先回滚消息列表，再设置错误状态（UI 会显示错误提示）
        state = AsyncValue.data(current);
        state = AsyncValue.error(e, StackTrace.current);
        // StackTrace.current：当前调用栈，用于调试
      }
    } catch (e, st) {
      // 捕获所有其他异常（catch 不指定类型时捕获所有）
      // st 是 StackTrace（调用栈信息）
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    } finally {
      // finally 块无论成功/失败/取消都会执行，类似 Python 的 finally
      _cancelToken = null;          // 清除取消令牌
      onSendingChanged?.call(false); // 通知 UI 退出"发送中"状态
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
  // 返回 String?：识别成功返回文字，失败返回 null
  Future<String?> recognizeOcr(String imageBase64) async {
    try {
      final result = await _service.recognizeImage(imageBase64);
      return result.text;
    } catch (_) {
      // _ 表示忽略异常对象（不需要用到它）
      return null; // 识别失败时静默返回 null，不影响主流程
    }
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
}
