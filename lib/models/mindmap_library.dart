import 'subject.dart';

// ── SubjectWithProgress ───────────────────────────────────────────────────────

class SubjectWithProgress {
  final Subject subject;
  final int totalNodes;
  final int litNodes;
  final int sessionCount;
  final DateTime? lastVisitedAt;

  const SubjectWithProgress({
    required this.subject,
    required this.totalNodes,
    required this.litNodes,
    required this.sessionCount,
    this.lastVisitedAt,
  });

  factory SubjectWithProgress.fromJson(Map<String, dynamic> json) {
    return SubjectWithProgress(
      subject: Subject.fromJson(json),
      totalNodes: (json['total_nodes'] as num?)?.toInt() ?? 0,
      litNodes: (json['lit_nodes'] as num?)?.toInt() ?? 0,
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 0,
      lastVisitedAt: json['last_visited_at'] != null
          ? DateTime.parse(json['last_visited_at'] as String)
          : null,
    );
  }
}

// ── MindMapSession ────────────────────────────────────────────────────────────

class MindMapSession {
  final int id;
  final String? title;
  final String? resourceScopeLabel;
  final DateTime createdAt;
  final int totalNodes;
  final int litNodes;
  final bool isPinned;
  final int sortOrder;

  const MindMapSession({
    required this.id,
    this.title,
    this.resourceScopeLabel,
    required this.createdAt,
    required this.totalNodes,
    required this.litNodes,
    this.isPinned = false,
    this.sortOrder = 0,
  });

  factory MindMapSession.fromJson(Map<String, dynamic> json) {
    return MindMapSession(
      id: json['id'] as int,
      title: json['title'] as String?,
      resourceScopeLabel: json['resource_scope_label'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      totalNodes: (json['total_nodes'] as num?)?.toInt() ?? 0,
      litNodes: (json['lit_nodes'] as num?)?.toInt() ?? 0,
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── TreeNode ──────────────────────────────────────────────────────────────────

class TreeNode {
  final String nodeId;
  final String text;
  final int depth; // 1-4
  final String? parentId;
  final bool isUserCreated;
  final List<TreeNode> children;
  bool isExpanded;

  TreeNode({
    required this.nodeId,
    required this.text,
    required this.depth,
    this.parentId,
    this.isUserCreated = false,
    List<TreeNode>? children,
    this.isExpanded = true,
  }) : children = children ?? [];

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      nodeId: json['node_id'] as String,
      text: json['text'] as String,
      depth: (json['depth'] as num).toInt(),
      parentId: json['parent_id'] as String?,
      isUserCreated: json['is_user_created'] as bool? ?? false,
    );
  }

  /// Build a tree from a flat list of nodes (with parent_id references).
  static List<TreeNode> buildTree(List<Map<String, dynamic>> flatList) {
    final map = <String, TreeNode>{};
    final roots = <TreeNode>[];

    for (final json in flatList) {
      map[json['node_id'] as String] = TreeNode.fromJson(json);
    }
    for (final node in map.values) {
      if (node.parentId == null) {
        roots.add(node);
      } else {
        map[node.parentId]?.children.add(node);
      }
    }
    return roots;
  }
}

// ── MindMapProgress ───────────────────────────────────────────────────────────

class MindMapProgress {
  final int total;
  final int lit;

  const MindMapProgress({required this.total, required this.lit});

  const MindMapProgress.empty() : total = 0, lit = 0;

  int get percent => total == 0 ? 0 : (lit / total * 100).floor();

  static MindMapProgress calculate(List<TreeNode> allNodes, Map<String, bool> states) {
    final total = allNodes.length;
    final lit = allNodes.where((n) => states[n.nodeId] == true).length;
    return MindMapProgress(total: total, lit: lit);
  }
}

// ── LectureBlock / LectureContent ─────────────────────────────────────────────

class LectureSpan {
  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool code;

  const LectureSpan({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  factory LectureSpan.fromJson(Map<String, dynamic> json) => LectureSpan(
        start: (json['start'] as num).toInt(),
        end: (json['end'] as num).toInt(),
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        code: json['code'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        if (bold) 'bold': true,
        if (italic) 'italic': true,
        if (code) 'code': true,
      };
}

class LectureBlock {
  final String id;
  final String type; // heading | paragraph | code | list | quote
  final int? level; // heading only
  final String text;
  final String source; // ai | user
  final String? language; // code only
  final List<LectureSpan> spans;
  final String? style; // warning etc.

  const LectureBlock({
    required this.id,
    required this.type,
    this.level,
    required this.text,
    required this.source,
    this.language,
    this.spans = const [],
    this.style,
  });

  factory LectureBlock.fromJson(Map<String, dynamic> json) => LectureBlock(
        id: json['id'] as String,
        type: json['type'] as String,
        level: json['level'] != null ? (json['level'] as num).toInt() : null,
        text: json['text'] as String? ?? '',
        source: json['source'] as String? ?? 'ai',
        language: json['language'] as String?,
        spans: (json['spans'] as List<dynamic>?)
                ?.map((e) => LectureSpan.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        style: json['style'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (level != null) 'level': level,
        'text': text,
        'source': source,
        if (language != null) 'language': language,
        if (spans.isNotEmpty) 'spans': spans.map((s) => s.toJson()).toList(),
        if (style != null) 'style': style,
      };
}

class LectureContent {
  final int version;
  final List<LectureBlock> blocks;

  const LectureContent({this.version = 1, required this.blocks});

  factory LectureContent.fromJson(Map<String, dynamic> json) => LectureContent(
        version: (json['version'] as num?)?.toInt() ?? 1,
        blocks: (json['blocks'] as List<dynamic>)
            .map((e) => LectureBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };
}
