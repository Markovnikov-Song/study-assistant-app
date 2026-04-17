import 'package:uuid/uuid.dart';

import '../../../models/mindmap_library.dart';
import '../models/mindmap_exception.dart';

/// Core domain object for all node tree mutation operations.
/// Pure Dart class — no Flutter dependencies.
///
/// Requirements: 1.1–1.5, 2.2–2.4, 3.1–3.3, 4.1–4.5
class NodeTreeEditor {
  List<TreeNode> roots;

  NodeTreeEditor(this.roots);

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Find a node by id across the entire tree. Returns null if not found.
  TreeNode? _findNode(String nodeId) {
    for (final root in roots) {
      final found = _findInSubtree(root, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  TreeNode? _findInSubtree(TreeNode node, String nodeId) {
    if (node.nodeId == nodeId) return node;
    for (final child in node.children) {
      final found = _findInSubtree(child, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  /// Find the parent of [nodeId]. Returns null if nodeId is a root or not found.
  TreeNode? _findParent(String nodeId) {
    for (final root in roots) {
      final found = _findParentInSubtree(root, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  TreeNode? _findParentInSubtree(TreeNode node, String targetId) {
    for (final child in node.children) {
      if (child.nodeId == targetId) return node;
      final found = _findParentInSubtree(child, targetId);
      if (found != null) return found;
    }
    return null;
  }

  /// Recursively update depth and parentId for a node and all its descendants
  /// after a move operation.
  TreeNode _rebuildDepths(TreeNode node, int newDepth, String? newParentId) {
    final updatedChildren = node.children
        .map((c) => _rebuildDepths(c, newDepth + 1, node.nodeId))
        .toList();
    return TreeNode(
      nodeId: node.nodeId,
      text: node.text,
      depth: newDepth,
      parentId: newParentId,
      isUserCreated: node.isUserCreated,
      children: updatedChildren,
      isExpanded: node.isExpanded,
    );
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Add a child node under [parentId].
  ///
  /// Returns the new [TreeNode], or null if [text] is blank.
  /// Throws [MaxDepthExceeded] if parent depth >= 6.
  ///
  /// Requirement: 1.1, 1.5
  TreeNode? addChild(String parentId, String text) {
    if (text.trim().isEmpty) return null;

    final parent = _findNode(parentId);
    if (parent == null) return null;

    if (parent.depth >= 6) {
      throw MaxDepthExceeded(attemptedDepth: parent.depth + 1);
    }

    final newNode = TreeNode(
      nodeId: const Uuid().v4(),
      text: text,
      depth: parent.depth + 1,
      parentId: parentId,
      isUserCreated: true,
    );
    parent.children.add(newNode);
    return newNode;
  }

  /// Insert a sibling node immediately after [nodeId] in the parent's children.
  ///
  /// Returns the new [TreeNode], or null if [text] is blank.
  ///
  /// Requirement: 1.2
  TreeNode? addSibling(String nodeId, String text) {
    if (text.trim().isEmpty) return null;

    final parent = _findParent(nodeId);
    if (parent == null) return null; // nodeId is a root — no sibling insertion

    final index = parent.children.indexWhere((c) => c.nodeId == nodeId);
    if (index == -1) return null;

    final newNode = TreeNode(
      nodeId: const Uuid().v4(),
      text: text,
      depth: parent.children[index].depth,
      parentId: parent.nodeId,
      isUserCreated: true,
    );
    parent.children.insert(index + 1, newNode);
    return newNode;
  }

  /// Update the text of [nodeId]. Truncates to 200 characters.
  ///
  /// Requirement: 2.2, 2.4
  void updateText(String nodeId, String text) {
    final node = _findNode(nodeId);
    if (node == null) return;

    final truncated = text.length > 200 ? text.substring(0, 200) : text;

    // TreeNode fields are final — replace in parent's children list.
    _replaceNode(
      nodeId,
      TreeNode(
        nodeId: node.nodeId,
        text: truncated,
        depth: node.depth,
        parentId: node.parentId,
        isUserCreated: node.isUserCreated,
        children: node.children,
        isExpanded: node.isExpanded,
      ),
    );
  }

  /// Replace the node with [nodeId] in-place (in parent's children or roots).
  void _replaceNode(String nodeId, TreeNode replacement) {
    // Check roots first
    for (int i = 0; i < roots.length; i++) {
      if (roots[i].nodeId == nodeId) {
        roots[i] = replacement;
        return;
      }
    }
    // Search in subtrees
    for (final root in roots) {
      if (_replaceInSubtree(root, nodeId, replacement)) return;
    }
  }

  bool _replaceInSubtree(
      TreeNode node, String targetId, TreeNode replacement) {
    for (int i = 0; i < node.children.length; i++) {
      if (node.children[i].nodeId == targetId) {
        node.children[i] = replacement;
        return true;
      }
      if (_replaceInSubtree(node.children[i], targetId, replacement)) {
        return true;
      }
    }
    return false;
  }

  /// Delete [nodeId] and all its descendants.
  ///
  /// Throws [CannotDeleteRoot] if [nodeId] is a root node.
  ///
  /// Requirement: 3.2, 3.3
  void deleteNode(String nodeId) {
    // Check if it's a root
    if (roots.any((r) => r.nodeId == nodeId)) {
      throw CannotDeleteRoot(nodeId: nodeId);
    }

    final parent = _findParent(nodeId);
    if (parent == null) return;
    parent.children.removeWhere((c) => c.nodeId == nodeId);
  }

  /// Move [nodeId] to become the last child of [targetId].
  ///
  /// Throws [CircularMove] if [targetId] is a descendant of [nodeId].
  ///
  /// Requirement: 4.3, 4.4
  void moveNode(String nodeId, String targetId) {
    if (isDescendant(nodeId, targetId)) {
      throw CircularMove(nodeId: nodeId, targetId: targetId);
    }

    final node = _findNode(nodeId);
    if (node == null) return;
    final target = _findNode(targetId);
    if (target == null) return;

    // Remove from current position
    final parent = _findParent(nodeId);
    if (parent != null) {
      parent.children.removeWhere((c) => c.nodeId == nodeId);
    } else {
      roots.removeWhere((r) => r.nodeId == nodeId);
    }

    // Rebuild depths and attach to target
    final moved = _rebuildDepths(node, target.depth + 1, targetId);
    target.children.add(moved);
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns true if [targetId] is a descendant of [ancestorId].
  ///
  /// Requirement: 4.4
  bool isDescendant(String ancestorId, String targetId) {
    final ancestor = _findNode(ancestorId);
    if (ancestor == null) return false;
    return _findInSubtree(ancestor, targetId) != null &&
        ancestor.nodeId != targetId;
  }

  /// Returns the depth (1-based) of [nodeId].
  ///
  /// Requirement: 1.5
  int nodeDepth(String nodeId) {
    final node = _findNode(nodeId);
    return node?.depth ?? -1;
  }

  /// Pre-order traversal of all nodes.
  ///
  /// Requirement: 3.2
  List<TreeNode> allNodes() {
    final result = <TreeNode>[];
    for (final root in roots) {
      _collectPreOrder(root, result);
    }
    return result;
  }

  void _collectPreOrder(TreeNode node, List<TreeNode> result) {
    result.add(node);
    for (final child in node.children) {
      _collectPreOrder(child, result);
    }
  }
}
