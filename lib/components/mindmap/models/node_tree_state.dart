import '../../../models/mindmap_library.dart';

/// Immutable state for the node tree editor.
///
/// Requirements: 4.1, 10.1
class NodeTreeState {
  /// The root nodes of the current mindmap tree.
  final List<TreeNode> roots;

  /// Whether there are unsaved changes.
  final bool isDirty;

  /// Timestamp of the last successful save, or null if never saved.
  final DateTime? lastSavedAt;

  /// The nodeId of the node currently being dragged, or null.
  final String? draggingNodeId;

  /// The nodeId of the node currently being hovered as a drop target, or null.
  final String? dropTargetId;

  const NodeTreeState({
    required this.roots,
    this.isDirty = false,
    this.lastSavedAt,
    this.draggingNodeId,
    this.dropTargetId,
  });

  /// Initial empty state.
  const NodeTreeState.empty()
      : roots = const [],
        isDirty = false,
        lastSavedAt = null,
        draggingNodeId = null,
        dropTargetId = null;

  NodeTreeState copyWith({
    List<TreeNode>? roots,
    bool? isDirty,
    DateTime? lastSavedAt,
    String? draggingNodeId,
    // Use a sentinel to allow explicitly setting nullable fields to null
    bool clearLastSavedAt = false,
    bool clearDraggingNodeId = false,
    bool clearDropTargetId = false,
    String? dropTargetId,
  }) {
    return NodeTreeState(
      roots: roots ?? this.roots,
      isDirty: isDirty ?? this.isDirty,
      lastSavedAt:
          clearLastSavedAt ? null : (lastSavedAt ?? this.lastSavedAt),
      draggingNodeId: clearDraggingNodeId
          ? null
          : (draggingNodeId ?? this.draggingNodeId),
      dropTargetId:
          clearDropTargetId ? null : (dropTargetId ?? this.dropTargetId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeTreeState &&
          runtimeType == other.runtimeType &&
          roots == other.roots &&
          isDirty == other.isDirty &&
          lastSavedAt == other.lastSavedAt &&
          draggingNodeId == other.draggingNodeId &&
          dropTargetId == other.dropTargetId;

  @override
  int get hashCode => Object.hash(
        roots,
        isDirty,
        lastSavedAt,
        draggingNodeId,
        dropTargetId,
      );

  @override
  String toString() => 'NodeTreeState('
      'roots: ${roots.length} nodes, '
      'isDirty: $isDirty, '
      'lastSavedAt: $lastSavedAt, '
      'draggingNodeId: $draggingNodeId, '
      'dropTargetId: $dropTargetId)';
}
