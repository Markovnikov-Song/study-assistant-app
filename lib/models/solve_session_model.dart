import 'package:uuid/uuid.dart';

// ── SolveMessage ──────────────────────────────────────────────────────────────

/// 解题会话中的单条消息。
class SolveMessage {
  final String role;                      // 'user' | 'assistant'
  final String content;                   // 消息文本内容
  final List<String>? imageBase64List;    // 仅用户消息携带图片
  final bool isSaved;                     // 是否已入库（笔记本/错题本）

  /// Python 计算引擎生成的图表 Base64（PNG），来自 [CHART] SSE 事件
  final String? chartBase64;

  const SolveMessage({
    required this.role,
    required this.content,
    this.imageBase64List,
    this.isSaved = false,
    this.chartBase64,
  });

  SolveMessage copyWith({
    String? role,
    String? content,
    List<String>? imageBase64List,
    bool? isSaved,
    String? chartBase64,
    bool clearChart = false,
  }) {
    return SolveMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      imageBase64List: imageBase64List ?? this.imageBase64List,
      isSaved: isSaved ?? this.isSaved,
      chartBase64: clearChart ? null : (chartBase64 ?? this.chartBase64),
    );
  }

  /// 转为 LLM messages 格式（追问时注入上下文）
  Map<String, dynamic> toLLMMessage() {
    return {'role': role, 'content': content};
  }
}

// ── SolveSessionModel ─────────────────────────────────────────────────────────

/// 一次完整的解题会话状态。
class SolveSessionModel {
  final String sessionId;

  /// 后端持久化后返回的 session_id（整数），用于追问时复用会话
  /// null 表示尚未收到后端 session_id（首次解题流式推送中）
  final int? backendSessionId;

  final List<String> imageBase64List;   // 原始图片，追问时复用（不重传）
  final String ocrText;                 // OCR 结果缓存
  final List<SolveMessage> messages;    // 对话历史
  final bool isThinkingExpanded;        // CoT 思维链展开状态（会话内持久化）
  final bool isStreaming;               // 当前是否正在流式接收

  const SolveSessionModel({
    required this.sessionId,
    this.backendSessionId,
    required this.imageBase64List,
    required this.ocrText,
    required this.messages,
    this.isThinkingExpanded = false,
    this.isStreaming = false,
  });

  /// 创建新的空会话
  factory SolveSessionModel.empty() {
    return SolveSessionModel(
      sessionId: const Uuid().v4(),
      imageBase64List: const [],
      ocrText: '',
      messages: const [],
    );
  }

  SolveSessionModel copyWith({
    String? sessionId,
    int? backendSessionId,
    bool clearBackendSessionId = false,
    List<String>? imageBase64List,
    String? ocrText,
    List<SolveMessage>? messages,
    bool? isThinkingExpanded,
    bool? isStreaming,
  }) {
    return SolveSessionModel(
      sessionId: sessionId ?? this.sessionId,
      backendSessionId: clearBackendSessionId
          ? null
          : (backendSessionId ?? this.backendSessionId),
      imageBase64List: imageBase64List ?? this.imageBase64List,
      ocrText: ocrText ?? this.ocrText,
      messages: messages ?? this.messages,
      isThinkingExpanded: isThinkingExpanded ?? this.isThinkingExpanded,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// 追加一条消息
  SolveSessionModel addMessage(SolveMessage message) {
    return copyWith(messages: [...messages, message]);
  }

  /// 更新最后一条消息（流式追加 token 时使用）
  SolveSessionModel updateLastMessage(String appendContent) {
    if (messages.isEmpty) return this;
    final last = messages.last;
    final updated = last.copyWith(content: last.content + appendContent);
    return copyWith(
      messages: [...messages.sublist(0, messages.length - 1), updated],
    );
  }

  /// 将对话历史转为 LLM messages 格式（追问时注入上下文）
  List<Map<String, dynamic>> toLLMHistory() {
    return messages.map((m) => m.toLLMMessage()).toList();
  }
}
