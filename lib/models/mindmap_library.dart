import 'package:uuid/uuid.dart';

import 'subject.dart';

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

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

  /// 三层综合进度 0.0~1.0（从 /progress 端点懒加载，初始为 null）
  final double? overallProgress;

  const MindMapSession({
    required this.id,
    this.title,
    this.resourceScopeLabel,
    required this.createdAt,
    required this.totalNodes,
    required this.litNodes,
    this.isPinned = false,
    this.sortOrder = 0,
    this.overallProgress,
  });

  factory MindMapSession.fromJson(Map<String, dynamic> json) {
    return MindMapSession(
      id: _toInt(json['id']),
      title: json['title'] as String?,
      resourceScopeLabel: json['resource_scope_label'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      totalNodes: (json['total_nodes'] as num?)?.toInt() ?? 0,
      litNodes: (json['lit_nodes'] as num?)?.toInt() ?? 0,
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      overallProgress: (json['overall_progress'] as num?)?.toDouble(),
    );
  }

  MindMapSession copyWith({double? overallProgress}) => MindMapSession(
        id: id,
        title: title,
        resourceScopeLabel: resourceScopeLabel,
        createdAt: createdAt,
        totalNodes: totalNodes,
        litNodes: litNodes,
        isPinned: isPinned,
        sortOrder: sortOrder,
        overallProgress: overallProgress ?? this.overallProgress,
      );
}

// ── TreeNode ──────────────────────────────────────────────────────────────────

class TreeNode {
  final String nodeId;
  final String text;
  final int depth; // 1-6
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

  Map<String, dynamic> toJson() => {
        'node_id': nodeId,
        'text': text,
        'depth': depth,
        if (parentId != null) 'parent_id': parentId,
        'is_user_created': isUserCreated,
        'children': children.map((c) => c.toJson()).toList(),
      };

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      // Backward compat: generate UUID if node_id is absent
      nodeId: json['node_id'] as String? ?? const Uuid().v4(),
      text: json['text'] as String,
      depth: _toInt(json['depth'], fallback: 1),
      // Backward compat: parentId absent → null
      parentId: json['parent_id'] as String?,
      // Backward compat: isUserCreated absent → false
      isUserCreated: json['is_user_created'] as bool? ?? false,
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => TreeNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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

/// 节点重要度权重：叶节点（无子节点）权重最高，根节点最低。
/// depth 1 = 0.4，depth 2 = 0.7，depth 3+ = 1.0；叶节点额外 ×1.5。
double _nodeWeight(TreeNode node) {
  final depthWeight = switch (node.depth) {
    1 => 0.4,
    2 => 0.7,
    _ => 1.0,
  };
  final leafBonus = node.children.isEmpty ? 1.5 : 1.0;
  return depthWeight * leafBonus;
}

class MindMapProgress {
  final int total;
  final int lit;

  /// 加权完成率 0.0~1.0（叶节点权重更高）
  final double weightedScore;

  /// 三层进度（从后端 /progress 端点加载后填充，否则为 null）
  final double? readProgress;
  final double? practiceProgress;
  final double? masteryProgress;
  final double? overallProgress;
  final int? mistakeCount;
  final int? reviewedMistakeCount;

  const MindMapProgress({
    required this.total,
    required this.lit,
    required this.weightedScore,
    this.readProgress,
    this.practiceProgress,
    this.masteryProgress,
    this.overallProgress,
    this.mistakeCount,
    this.reviewedMistakeCount,
  });

  const MindMapProgress.empty()
      : total = 0,
        lit = 0,
        weightedScore = 0.0,
        readProgress = null,
        practiceProgress = null,
        masteryProgress = null,
        overallProgress = null,
        mistakeCount = null,
        reviewedMistakeCount = null;

  /// 简单计数百分比（用于进度条文字显示）
  int get percent => total == 0 ? 0 : (lit / total * 100).floor();

  /// 加权百分比（用于进度条宽度）
  int get weightedPercent => (weightedScore * 100).floor();

  /// 综合进度（优先用后端三层计算值，否则用本地加权分数）
  double get displayScore => overallProgress ?? weightedScore;

  static MindMapProgress calculate(
      List<TreeNode> allNodes, Map<String, bool> states) {
    if (allNodes.isEmpty) return const MindMapProgress.empty();

    final total = allNodes.length;
    final lit = allNodes.where((n) => states[n.nodeId] == true).length;

    // 加权分数：每个节点按权重贡献，点亮则计入分子
    double weightSum = 0.0;
    double litWeightSum = 0.0;
    for (final node in allNodes) {
      final w = _nodeWeight(node);
      weightSum += w;
      if (states[node.nodeId] == true) litWeightSum += w;
    }
    final weightedScore = weightSum == 0 ? 0.0 : litWeightSum / weightSum;

    return MindMapProgress(
      total: total,
      lit: lit,
      weightedScore: weightedScore,
    );
  }

  /// 用后端三层进度数据合并，返回新实例
  MindMapProgress withServerProgress(Map<String, dynamic> json) {
    return MindMapProgress(
      total: (json['total_nodes'] as num?)?.toInt() ?? total,
      lit: (json['lit_nodes'] as num?)?.toInt() ?? lit,
      weightedScore: weightedScore,
      readProgress: (json['read_progress'] as num?)?.toDouble(),
      practiceProgress: (json['practice_progress'] as num?)?.toDouble(),
      masteryProgress: (json['mastery_progress'] as num?)?.toDouble(),
      overallProgress: (json['overall_progress'] as num?)?.toDouble(),
      mistakeCount: (json['mistake_count'] as num?)?.toInt(),
      reviewedMistakeCount: (json['reviewed_mistake_count'] as num?)?.toInt(),
    );
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
        start: _toInt(json['start']),
        end: _toInt(json['end']),
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
        level: json['level'] != null ? _toInt(json['level']) : null,
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

// ── KnowledgeLink ─────────────────────────────────────────────────────────────

class KnowledgeLink {
  final int id;
  final String sourceNodeId;
  final String targetNodeId;
  final String sourceNodeText;
  final String targetNodeText;
  final String linkType; // causal | dependency | contrast | evolution
  final String rationale;

  const KnowledgeLink({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.sourceNodeText,
    required this.targetNodeText,
    required this.linkType,
    required this.rationale,
  });

  factory KnowledgeLink.fromJson(Map<String, dynamic> json) => KnowledgeLink(
        id: _toInt(json['id']),
        sourceNodeId: json['source_node_id'] as String? ?? '',
        targetNodeId: json['target_node_id'] as String? ?? '',
        sourceNodeText: json['source_node_text'] as String? ?? '',
        targetNodeText: json['target_node_text'] as String? ?? '',
        linkType: json['link_type'] as String? ?? 'causal',
        rationale: json['rationale'] as String? ?? '',
      );
}
