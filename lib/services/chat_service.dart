// ─────────────────────────────────────────────────────────────
// chat_service.dart — 聊天相关的 HTTP 请求封装
// 相当于 Python 里用 requests 库调用后端 API 的那层代码
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/network/dio_client.dart';
import '../core/storage/storage_service.dart';
import '../models/chat_message.dart';

import 'package:study_assistant_app/tools/network/sse_client_stub.dart'
    if (dart.library.html) 'package:study_assistant_app/tools/network/sse_client_web.dart'
    if (dart.library.io) 'package:study_assistant_app/tools/network/sse_client_native.dart';

// ─── 发送消息的返回结果 ──────────────────────────────────────
// 把多个返回值打包成一个类，类似 Python 的 NamedTuple 或 dataclass
class ChatSendResult {
  final ChatMessage message;    // AI 回复的消息
  final int sessionId;          // 本次对话的会话 ID（服务器分配）
  final bool needsConfirmation; // 是否需要用户确认（strict 模式找不到资料时）

  // {} 里的参数是"命名参数"，调用时必须写参数名
  // this.needsConfirmation = false 表示默认值是 false（可以不传）
  ChatSendResult({required this.message, required this.sessionId, this.needsConfirmation = false});
}

// ─── OCR 识别结果 ────────────────────────────────────────────
class OcrResult {
  final String text; // 识别出的文字
  OcrResult({required this.text});
}

// ─── 聊天服务类 ──────────────────────────────────────────────
class ChatService {
  // 获取全局唯一的 Dio HTTP 客户端实例（单例模式）
  // 类似 Python 的 session = requests.Session()
  final Dio _dio = DioClient.instance.dio;
  // _ 开头表示私有字段，只能在这个类内部访问（类似 Python 的 __dio）

  // ─── 获取某学科下的所有对话会话列表 ──────────────────────
  // Future<T>：异步返回值，类似 Python 的 async def 返回 Coroutine
  // Future<List<ConversationSession>> 表示"将来会返回一个会话列表"
  Future<List<ConversationSession>> getSessions(int subjectId) async {
    try {
      // await：等待异步操作完成，类似 Python 的 await
      // GET /api/sessions/subject/{subjectId}
      // 字符串插值：'${变量}' 类似 Python 的 f'{变量}'
      final res = await _dio.get('${ApiConstants.sessions}/subject/$subjectId');

      // res.data 是服务器返回的 JSON 数据（已自动解析）
      // as List：强制类型转换，告诉编译器这是个列表
      // .map((e) => ...)：对列表每个元素做转换，类似 Python 的 map()
      // .toList()：把 Iterable 转成 List
      return (res.data as List).map((e) => ConversationSession.fromJson(e)).toList();
    } on DioException catch (e) {
      // on XxxException catch (e)：捕获特定类型的异常
      // 类似 Python 的 except DioException as e:
      // 把 Dio 的底层异常转成我们自定义的 ApiException（含中文提示）
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 获取某会话的历史消息列表 ─────────────────────────────
  Future<List<ChatMessage>> getSessionHistory(int sessionId) async {
    try {
      final res = await _dio.get('${ApiConstants.sessions}/$sessionId/history');
      return (res.data as List).map((e) => ChatMessage.fromJson(e)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 发送消息（核心方法）─────────────────────────────────
  // {} 里是命名参数，required 表示必传，没有 required 的有默认值
  Future<ChatSendResult> sendMessage(
    String message, {          // 用户输入的文本（位置参数，必须第一个传）
    required int subjectId,    // 当前学科 ID
    int? sessionId,            // 会话 ID，? 表示可为 null（新对话时不传）
    required SessionType mode, // 模式：qa/solve/mindmap/exam
    bool useBroad = false,     // 是否用 broad 模式（知识库+通用知识混合）
    bool useHybrid = false,    // 是否用 hybrid 模式（知识库优先，失败降级）
    CancelToken? cancelToken,  // 取消令牌，用于中途取消请求
  }) async {
    try {
      // 根据参数决定实际发给后端的 mode 字符串
      String modeStr;
      if (useHybrid) {
        modeStr = 'hybrid'; // 勾选"结合通用知识"时用这个
      } else if (useBroad) {
        modeStr = 'broad';  // 旧的 broad 模式（保留兼容）
      } else {
        modeStr = mode.name; // 枚举转字符串：SessionType.qa.name == "qa"
      }

      // POST /api/chat/query，发送 JSON 请求体
      final res = await _dio.post(ApiConstants.chatQuery,
        data: {
          'message': message,
          'subject_id': subjectId,
          'session_id': ?sessionId, // ?变量 是 Dart 的空感知展开，null 时不包含这个键
          'mode': modeStr,
        },
        cancelToken: cancelToken, // 传入取消令牌，用户点停止时可以中断请求
      );

      // 解析响应 JSON
      final data = res.data as Map<String, dynamic>;

      // 检查是否需要用户确认（strict 模式找不到相关资料时后端返回 true）
      final needsConfirm = data['needs_confirmation'] as bool? ?? false;
      if (needsConfirm) {
        // 返回一个空消息，UI 层会显示提示文字
        return ChatSendResult(
          message: ChatMessage.local(role: MessageRole.assistant, content: ''),
          sessionId: (data['session_id'] as num).toInt(),
          needsConfirmation: true,
        );
      }

      // 正常情况：解析 AI 回复消息
      return ChatSendResult(
        message: ChatMessage.fromJson(data['message']),
        sessionId: (data['session_id'] as num).toInt(),
      );
    } on DioException catch (e) {
      // DioException 会在请求被取消时也抛出，上层 provider 会区分处理
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 流式发送消息（SSE）─────────────────────────────────
  Stream<String> sendMessageStream(
    String message, {
    required int subjectId,
    int? sessionId,
    required SessionType mode,
    bool useHybrid = false,
  }) async* {
    final modeStr = useHybrid ? 'hybrid' : _toBackendMode(mode);
    final token = await _getAuthToken();
    final url = '${_dio.options.baseUrl}${ApiConstants.chatQueryStream}';

    final body = <String, dynamic>{
      'message': message,
      'subject_id': subjectId,
      'mode': modeStr,
      // ignore: use_null_aware_elements
      if (sessionId != null) 'session_id': sessionId,
    };

    yield* ssePost(url, body, token);
  }

  /// SessionType → 后端 mode 字符串映射
  String _toBackendMode(SessionType mode) {
    switch (mode) {
      case SessionType.qa:      return 'strict';
      case SessionType.solve:   return 'solve';
      case SessionType.mindmap: return 'strict';
      case SessionType.exam:    return 'strict';
      case SessionType.feynman: return 'feynman';
    }
  }

  Future<String?> _getAuthToken() async {
    try {
      return await StorageService.instance.getToken();
    } catch (_) {
      return null;
    }
  }
  Future<String> generateMindMap(int subjectId, {int? sessionId, int? docId}) async {
    try {
      final res = await _dio.post(ApiConstants.chatMindmap, data: {
        'subject_id': subjectId,
        'session_id': ?sessionId, // null 时不包含这个键
        'doc_id': ?docId,
      });
      return (res.data as Map<String, dynamic>)['content'] as String? ?? ''; // 返回 markmap 格式的 Markdown 文本
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 生成自定义思维导图（用户输入主题，不依赖资料库）────
  Future<String> generateCustomMindMap(String topic, {int? subjectId}) async {
    try {
      final res = await _dio.post(ApiConstants.chatMindmapCustom, data: {
        'topic': topic,
        'subject_id': ?subjectId,
      });
      return (res.data as Map<String, dynamic>)['content'] as String? ?? '';
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 删除对话会话 ─────────────────────────────────────────
  Future<void> deleteSession(int sessionId) async {
    // void 表示没有返回值，类似 Python 的 -> None
    try {
      await _dio.delete('${ApiConstants.sessions}/$sessionId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ─── 图片 OCR 识别 ────────────────────────────────────────
  Future<OcrResult> recognizeImage(String imageBase64) async {
    try {
      // 把 base64 编码的图片发给后端，后端调用视觉模型识别文字
      final res = await _dio.post(ApiConstants.ocrImage, data: {'image': imageBase64});
      return OcrResult(text: (res.data as Map<String, dynamic>)['text'] as String? ?? '');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
