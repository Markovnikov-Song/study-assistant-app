import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../models/chat_message.dart';

class ChatSendResult {
  final ChatMessage message;
  final int sessionId;
  final bool needsConfirmation;
  ChatSendResult({required this.message, required this.sessionId, this.needsConfirmation = false});
}

class OcrResult {
  final String text;
  OcrResult({required this.text});
}

class ChatService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<ConversationSession>> getSessions(int subjectId) async {
    try {
      final res = await _dio.get('${ApiConstants.sessions}/subject/$subjectId');      return (res.data as List).map((e) => ConversationSession.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ChatMessage>> getSessionHistory(int sessionId) async {
    try {
      final res = await _dio.get('${ApiConstants.sessions}/$sessionId/history');
      return (res.data as List).map((e) => ChatMessage.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// mode: strict | broad | solve
  Future<ChatSendResult> sendMessage(
    String message, {
    required int subjectId,
    int? sessionId,
    required SessionType mode,
    bool useBroad = false,
  }) async {
    try {
      final modeStr = useBroad ? 'broad' : mode.name;
      final res = await _dio.post(ApiConstants.chatQuery, data: {
        'message': message,
        'subject_id': subjectId,
        if (sessionId != null) 'session_id': sessionId,
        'mode': modeStr,
      });
      final data = res.data as Map<String, dynamic>;
      final needsConfirm = data['needs_confirmation'] as bool? ?? false;
      if (needsConfirm) {
        return ChatSendResult(
          message: ChatMessage.local(role: MessageRole.assistant, content: ''),
          sessionId: data['session_id'] as int,
          needsConfirmation: true,
        );
      }
      return ChatSendResult(
        message: ChatMessage.fromJson(data['message']),
        sessionId: data['session_id'] as int,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<String> generateMindMap(int subjectId, {int? sessionId, int? docId}) async {
    try {
      final res = await _dio.post(ApiConstants.chatMindmap, data: {
        'subject_id': subjectId,
        if (sessionId != null) 'session_id': sessionId,
        if (docId != null) 'doc_id': docId,
      });
      return res.data['content'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<OcrResult> recognizeImage(String imageBase64) async {
    try {
      final res = await _dio.post(ApiConstants.ocrImage, data: {'image': imageBase64});
      return OcrResult(text: res.data['text'] as String);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
