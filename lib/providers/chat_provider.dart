import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// key = (subjectId, sessionType.name)，问答/解题/导图各自独立
final chatProvider = StateNotifierProviderFamily<ChatNotifier, AsyncValue<List<ChatMessage>>, (int, String)>(
  (ref, key) => ChatNotifier(ref.watch(chatServiceProvider), key.$1),
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
        // 找不到相关资料，提示用户
        final hint = ChatMessage.local(
          role: MessageRole.assistant,
          content: useBroad
              ? '暂未找到相关资料，请先在「资料管理」上传学科资料后再试。'
              : '在已上传资料中未找到相关内容。\n\n可以勾选「结合通用知识」后重新提问，AI 将基于通用知识回答并标注来源。',
        );
        state = AsyncValue.data([...state.value!, hint]);
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
