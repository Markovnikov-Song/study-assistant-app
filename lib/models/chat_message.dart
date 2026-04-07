enum MessageRole { user, assistant }

enum SessionType { qa, solve, mindmap, exam }

class ChatMessage {
  final int id;
  final MessageRole role;
  final String content;
  final List<MessageSource>? sources;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sources,
    required this.createdAt,
  });

  bool get isUser => role == MessageRole.user;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        content: json['content'] as String,
        sources: (json['sources'] as List?)
            ?.map((e) => MessageSource.fromJson(e))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  // 本地乐观更新用
  factory ChatMessage.local({required MessageRole role, required String content}) =>
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        role: role,
        content: content,
        createdAt: DateTime.now(),
      );
}

class MessageSource {
  final String filename;
  final int chunkIndex;
  final String content;
  final double score;

  const MessageSource({
    required this.filename,
    required this.chunkIndex,
    required this.content,
    required this.score,
  });

  factory MessageSource.fromJson(Map<String, dynamic> json) => MessageSource(
        filename: json['filename'] as String,
        chunkIndex: json['chunk_index'] as int,
        content: json['content'] as String,
        score: (json['score'] as num).toDouble(),
      );
}

class ConversationSession {
  final int id;
  final SessionType sessionType;
  final String? title;
  final DateTime createdAt;

  const ConversationSession({
    required this.id,
    required this.sessionType,
    this.title,
    required this.createdAt,
  });

  String get typeLabel {
    switch (sessionType) {
      case SessionType.qa: return '💬 问答';
      case SessionType.solve: return '🔢 解题';
      case SessionType.mindmap: return '🗺 思维导图';
      case SessionType.exam: return '🤖 出题';
    }
  }

  factory ConversationSession.fromJson(Map<String, dynamic> json) {
    final typeStr = json['session_type'] as String;
    final type = SessionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => SessionType.qa,
    );
    return ConversationSession(
      id: json['id'] as int,
      sessionType: type,
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
