// ─────────────────────────────────────────────────────────────
// chat_message.dart — 聊天相关的数据模型
// 相当于 Python 的 dataclass，只存数据，不含业务逻辑
// ─────────────────────────────────────────────────────────────

// enum（枚举）：一组固定的命名常量，类似 Python 的 Enum
// 消息角色：用户 or AI 助手
enum MessageRole { user, assistant }

// 消息类型：普通文本 or 场景识别卡片
enum MessageType { text, sceneCard }

// 场景类型：学科 / 规划 / 工具 / Spec
enum SceneType { subject, planning, tool, spec }

// 场景卡片数据（纯本地状态，不来自服务器）
// dismissed 需要可变，所以不用 const，也不用 final
class SceneCardData {
  final SceneType sceneType;
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final String dismissLabel;
  final Map<String, dynamic> payload;
  bool dismissed;

  SceneCardData({
    required this.sceneType,
    required this.title,
    this.subtitle,
    required this.confirmLabel,
    required this.dismissLabel,
    required this.payload,
    this.dismissed = false,
  });
}

// 会话类型：问答 / 解题 / 思维导图 / 出题
// .name 属性会返回枚举值的字符串名，如 SessionType.qa.name == "qa"
enum SessionType { qa, solve, mindmap, exam }

// ─── 单条聊天消息 ───────────────────────────────────────────
// class 相当于 Python 的 class，但 Dart 默认所有字段都是 public
// final 表示字段赋值后不可修改，类似 Python 的 frozen dataclass
class ChatMessage {
  final int id;              // 消息 ID（数据库主键）
  final MessageRole role;    // 谁发的：user 或 assistant
  final String content;      // 消息文本内容
  final List<MessageSource>? sources; // RAG 参考来源列表，? 表示可以为 null
  final DateTime createdAt;  // 创建时间
  final MessageType type;    // 消息类型，默认 text
  SceneCardData? sceneCardData; // type == sceneCard 时非空（可变，dismissed 需要修改）

  // required 表示调用时必须传这个参数（类似 Python 函数的无默认值参数）
  // this.xxx 是 Dart 的简写，等价于 Python 的 self.xxx = xxx
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sources,       // 没有 required，所以可以不传（默认 null）
    required this.createdAt,
    this.type = MessageType.text,  // 新增，默认 text
    this.sceneCardData,            // 新增，默认 null
  });

  // get 是 Dart 的"计算属性"（getter），类似 Python 的 @property
  // 调用时写 message.isUser，不用加括号
  bool get isUser => role == MessageRole.user;
  // => 是单行函数的简写，等价于 { return role == MessageRole.user; }

  // factory 构造函数：从 JSON 数据创建对象，类似 Python 的 @classmethod
  // Map<String, dynamic>：键是 String，值是任意类型，等价于 Python 的 dict
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        // as num? 表示把值转成数字类型（可为 null）
        // ?. 是空安全调用，如果左边是 null 就不执行右边，直接返回 null
        // ?? 是空合并运算符，左边为 null 时取右边的值（类似 Python 的 or）
        id: (json['id'] as num?)?.toInt() ?? 0,

        // 根据字符串判断枚举值
        role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        // ? : 是三元运算符，等价于 Python 的 x if condition else y

        content: json['content'] as String? ?? '',

        // json['sources'] 是一个列表，用 map 把每个元素转成 MessageSource 对象
        // 类似 Python 的 [MessageSource.from_json(e) for e in json['sources']]
        sources: (json['sources'] as List?)
            ?.map((e) => MessageSource.fromJson(e))
            .toList(), // .toList() 把 Iterable 转成 List

        // 解析 ISO 8601 时间字符串，如 "2024-01-01T12:00:00"
        createdAt: json['created_at'] != null && (json['created_at'] as String).isNotEmpty
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  // 另一个 factory 构造函数：创建本地临时消息（不来自服务器）
  // 用于"乐观更新"——用户发消息后立刻显示，不等服务器响应
  factory ChatMessage.local({
    required MessageRole role,
    required String content,
    MessageType type = MessageType.text,
    SceneCardData? sceneCardData,
  }) =>
      ChatMessage(
        // 用当前时间戳作为临时 ID，保证唯一性
        id: DateTime.now().millisecondsSinceEpoch,
        role: role,
        content: content,
        createdAt: DateTime.now(),
        type: type,
        sceneCardData: sceneCardData,
      );
}

// ─── 参考来源（RAG 检索到的文档片段）────────────────────────
class MessageSource {
  final String filename;   // 来源文件名，如 "材料力学.pdf"
  final int chunkIndex;    // 第几个文本块（文档被切成多块）
  final String content;    // 该文本块的内容
  final double score;      // 相似度分数（越小越相关，cosine 距离）

  const MessageSource({
    required this.filename,
    required this.chunkIndex,
    required this.content,
    required this.score,
  });

  factory MessageSource.fromJson(Map<String, dynamic> json) => MessageSource(
        filename: json['filename'] as String? ?? '',
        chunkIndex: (json['chunk_index'] as num?)?.toInt() ?? 0,
        content: json['content'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
      );
}

// ─── 对话会话（一组连续的对话）──────────────────────────────
class ConversationSession {
  final int id;
  final SessionType sessionType; // 这个会话是问答/解题/导图/出题
  final String? title;           // 会话标题（AI 自动生成的关键词）
  final DateTime createdAt;

  const ConversationSession({
    required this.id,
    required this.sessionType,
    this.title,
    required this.createdAt,
  });

  // getter：返回会话类型的中文标签（带 emoji）
  String get typeLabel {
    // switch 语句，类似 Python 的 match-case
    switch (sessionType) {
      case SessionType.qa:      return '💬 问答';
      case SessionType.solve:   return '🔢 解题';
      case SessionType.mindmap: return '🗺 思维导图';
      case SessionType.exam:    return '🤖 出题';
    }
  }

  factory ConversationSession.fromJson(Map<String, dynamic> json) {
    final typeStr = json['session_type'] as String; // 从 JSON 取字符串，如 "qa"

    // SessionType.values 是所有枚举值的列表：[qa, solve, mindmap, exam]
    // firstWhere：找第一个满足条件的元素，类似 Python 的 next(filter(...))
    // e.name 是枚举值的字符串名，如 SessionType.qa.name == "qa"
    // orElse：找不到时的默认值（防止服务器返回未知类型时崩溃）
    final type = SessionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => SessionType.qa,
    );
    return ConversationSession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sessionType: type,
      title: json['title'] as String?,
      // .toLocal() 把 UTC 时间转成本地时区时间
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
