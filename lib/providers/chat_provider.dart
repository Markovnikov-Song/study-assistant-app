import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final chatProvider = StateNotifierProviderFamily<ChatNotifier, AsyncValue<List<ChatMessage>>, int>(
  (ref, subjectId) => ChatNotifier(ref.watch(chatServiceProvider), subjectId),
);

final sessionsProvider = FutureProviderFamily<List<ConversationSession>, int>(
  (ref, subjectId) => ref.watch(chatServiceProvider).getSessions(subjectId),
);

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatService _service;
  final int _subjectId;
  int? _currentSessionId;

  ChatNotifier(this._service, this._subjectId) : super(const AsyncValue.data([]));

  int? get currentSessionId => _currentSessionId;

  Future<void> sendMessage(
    String text, {
    required SessionType mode,
    bool useBroad = false,
  }) async {
    final current = List<ChatMessage>.from(state.value ?? []);
    final userMsg = ChatMessage.local(role: MessageRole.user, content: text);
    state = AsyncValue.data([...current, userMsg]);

    try {
      final result = await _service.sendMessage(
        text,
        subjectId: _subjectId,
        sessionId: _currentSessionId,
        mode: mode,
        useBroad: useBroad,
      );
      _currentSessionId = result.sessionId;
      if (result.needsConfirmation) {
        // 没有相关资料，自动用 broad 模式重试
        final retryResult = await _service.sendMessage(
          text,
          subjectId: _subjectId,
          sessionId: _currentSessionId,
          mode: mode,
          useBroad: true, // 强制 broad
        );
        if (!retryResult.needsConfirmation) {
          state = AsyncValue.data([...state.value!, retryResult.message]);
        }
        return;
      }
      state = AsyncValue.data([...state.value!, result.message]);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> generateMindMap({int? docId}) async {
    state = const AsyncValue.loading();
    try {
      final content = await _service.generateMindMap(
        _subjectId,
        sessionId: _currentSessionId,
        docId: docId,
      );
      // 用一条 assistant 消息存储 mindmap 内容
      final msg = ChatMessage.local(role: MessageRole.assistant, content: content);
      state = AsyncValue.data([msg]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> recognizeOcr(String imageBase64) async {
    try {
      final result = await _service.recognizeImage(imageBase64);
      return result.text;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadSession(int sessionId) async {
    state = const AsyncValue.loading();
    try {
      final messages = await _service.getSessionHistory(sessionId);
      _currentSessionId = sessionId;
      state = AsyncValue.data(messages);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void deleteMessage(int index) {
    final msgs = List<ChatMessage>.from(state.value ?? []);
    if (index >= 0 && index < msgs.length) {
      msgs.removeAt(index);
      state = AsyncValue.data(msgs);
    }
  }

  void newSession() {
    _currentSessionId = null;
    state = const AsyncValue.data([]);
  }
}
