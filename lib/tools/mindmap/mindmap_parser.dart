import '../../../models/mindmap_library.dart';

/// MindMapParser — parses Markdown headings into a TreeNode tree.
///
/// Node ID format: `L{depth}_{ancestor_path}_{text}`
/// Duplicate siblings get `_2`, `_3` suffix.
class MindMapParser {
  /// Parse [markdown] text and return a list of root TreeNodes (depth=1).
  /// Each root node has its children populated recursively.
  static List<TreeNode> parse(String markdown) {
    final lines = markdown.split('\n');
    final rawNodes = <_RawNode>[];

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) continue;

      int depth = 0;
      for (int i = 0; i < trimmed.length && trimmed[i] == '#'; i++) {
        depth++;
      }
      if (depth == 0 || depth > 6) continue;
      // Must have a space after the hashes
      if (trimmed.length <= depth || trimmed[depth] != ' ') continue;

      final text = trimmed.substring(depth + 1).trim();
      if (text.isEmpty) continue;

      rawNodes.add(_RawNode(depth: depth, text: text));
    }

    return _buildTree(rawNodes);
  }

  static List<TreeNode> _buildTree(List<_RawNode> rawNodes) {
    // Stack of (depth, nodeId) for ancestor path tracking
    final ancestorStack = <_StackEntry>[];
    final roots = <TreeNode>[];

    // Track sibling text counts at each (parentId, depth) level
    // key: "parentId|depth|text" → count
    final siblingCounts = <String, int>{};

    for (final raw in rawNodes) {
      // Pop stack entries that are at same or deeper depth
      while (ancestorStack.isNotEmpty &&
          ancestorStack.last.depth >= raw.depth) {
        ancestorStack.removeLast();
      }

      // Build ancestor path for ID
      final ancestorPath = ancestorStack.map((e) => e.text).join('_');
      final parentId =
          ancestorStack.isNotEmpty ? ancestorStack.last.nodeId : null;

      // Determine sibling key for deduplication
      final siblingKey = '${parentId ?? ''}|${raw.depth}|${raw.text}';
      final count = (siblingCounts[siblingKey] ?? 0) + 1;
      siblingCounts[siblingKey] = count;

      // Build node ID
      final baseId = ancestorPath.isEmpty
          ? 'L${raw.depth}_${raw.text}'
          : 'L${raw.depth}_${ancestorPath}_${raw.text}';
      final nodeId = count == 1 ? baseId : '${baseId}_$count';

      final node = TreeNode(
        nodeId: nodeId,
        text: raw.text,
        depth: raw.depth,
        parentId: parentId,
        isUserCreated: false,
        children: [],
        isExpanded: true,
      );

      if (parentId == null) {
        roots.add(node);
      } else {
        // Find parent in the tree and add child
        _addChild(roots, parentId, node);
      }

      ancestorStack.add(_StackEntry(
        depth: raw.depth,
        nodeId: nodeId,
        text: raw.text,
      ));
    }

    return roots;
  }

  static bool _addChild(
      List<TreeNode> nodes, String parentId, TreeNode child) {
    for (final node in nodes) {
      if (node.nodeId == parentId) {
        node.children.add(child);
        return true;
      }
      if (_addChild(node.children, parentId, child)) return true;
    }
    return false;
  }
}

class _RawNode {
  final int depth;
  final String text;
  _RawNode({required this.depth, required this.text});
}

class _StackEntry {
  final int depth;
  final String nodeId;
  final String text;
  _StackEntry({required this.depth, required this.nodeId, required this.text});
}
