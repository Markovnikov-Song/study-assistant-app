import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/core/network/dio_client.dart';
import 'package:study_assistant_app/models/chat_message.dart';
import 'package:study_assistant_app/providers/chat_provider.dart';
import 'package:study_assistant_app/services/chat_service.dart';

class _FakeChatService extends ChatService {
  @override
  Stream<String> sendMessageStream(
    String message, {
    required int subjectId,
    int? sessionId,
    required SessionType mode,
    bool useHybrid = false,
  }) async* {
    yield '[SESSION_ID:42]';
    yield '资料里说二次函数的顶点式可以直接读出顶点。';
    yield '[SOURCES]{"sources":[{"filename":"algebra.pdf","chunk_index":2,"content":"二次函数顶点式 y=a(x-h)^2+k 的顶点为 (h,k)。","score":0.12}]}';
    yield '[DONE]';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DioClient.instance.init();
  });

  test('streamed RAG sources are attached to assistant message', () async {
    final notifier = ChatNotifier(
      _FakeChatService(),
      chatKey: '11',
      subjectId: 11,
    );

    await notifier.sendMessage('顶点式怎么读顶点？', mode: SessionType.qa);

    final messages = notifier.state.value!;
    expect(messages, hasLength(2));
    expect(messages.last.role, MessageRole.assistant);
    expect(messages.last.content, contains('顶点式'));
    expect(messages.last.sources, isNotNull);
    expect(messages.last.sources, hasLength(1));
    expect(messages.last.sources!.first.filename, 'algebra.pdf');
    expect(messages.last.sources!.first.chunkIndex, 2);
  });
}
