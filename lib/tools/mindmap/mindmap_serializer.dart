import '../../../models/mindmap_library.dart';

/// MindMapSerializer — serializes a TreeNode tree back to Markdown.
///
/// User-created nodes and AI-generated nodes are serialized identically.
class MindMapSerializer {
  /// Serialize a list of root nodes to a Markdown string.
  static String serializeRoots(List<TreeNode> roots) {
    final buffer = StringBuffer();
    for (final root in roots) {
      _serializeNode(root, buffer);
    }
    return buffer.toString().trimRight();
  }

  /// Serialize a single root node (and its subtree) to Markdown.
  static String serialize(TreeNode root) {
    final buffer = StringBuffer();
    _serializeNode(root, buffer);
    return buffer.toString().trimRight();
  }

  static void _serializeNode(TreeNode node, StringBuffer buffer) {
    final hashes = '#' * node.depth;
    buffer.writeln('$hashes ${node.text}');
    for (final child in node.children) {
      _serializeNode(child, buffer);
    }
  }
}
