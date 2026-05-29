// 解题历史数据模型
//
// 对应后端 /api/solve/sessions 接口返回的数据结构。

// ── SolveHistorySession ───────────────────────────────────────────────────────

/// 历史会话列表条目（列表接口返回）
class SolveHistorySession {
  final int id;
  final String title;
  final DateTime createdAt;

  /// Base64 缩略图前 200 字符，可能为 null（无图片时）
  final String? thumbnail;

  const SolveHistorySession({
    required this.id,
    required this.title,
    required this.createdAt,
    this.thumbnail,
  });

  factory SolveHistorySession.fromJson(Map<String, dynamic> json) {
    return SolveHistorySession(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      thumbnail: json['thumbnail'] as String?,
    );
  }
}

// ── SolveHistoryMessage ───────────────────────────────────────────────────────

/// 历史会话中的单条消息（详情接口返回）
class SolveHistoryMessage {
  final int id;

  /// 'user' | 'assistant'
  final String role;
  final String content;

  /// 图片等附件，格式：{"images": ["b64..."]}，可能为 null
  final Map<String, dynamic>? sources;
  final DateTime createdAt;

  const SolveHistoryMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sources,
    required this.createdAt,
  });

  factory SolveHistoryMessage.fromJson(Map<String, dynamic> json) {
    return SolveHistoryMessage(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String? ?? '',
      sources: json['sources'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// 从 sources 中提取图片 Base64 列表
  List<String> get images =>
      (sources?['images'] as List?)?.cast<String>() ?? [];
}
