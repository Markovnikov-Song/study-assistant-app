/// Sealed exception hierarchy for all mindmap domain errors.
///
/// Requirements: 1.5, 3.3, 4.4, 10.6
sealed class MindmapException implements Exception {
  const MindmapException();

  @override
  String toString() => 'MindmapException';
}

/// Thrown when attempting to add a child node beyond the maximum depth (6).
///
/// Requirement: 1.5
final class MaxDepthExceeded extends MindmapException {
  final int maxDepth;
  final int attemptedDepth;

  const MaxDepthExceeded({
    this.maxDepth = 6,
    required this.attemptedDepth,
  });

  @override
  String toString() =>
      'MaxDepthExceeded: attempted depth $attemptedDepth exceeds max $maxDepth';
}

/// Thrown when attempting to delete the root node of a mindmap.
///
/// Requirement: 3.3
final class CannotDeleteRoot extends MindmapException {
  final String nodeId;

  const CannotDeleteRoot({required this.nodeId});

  @override
  String toString() => 'CannotDeleteRoot: node $nodeId is a root node';
}

/// Thrown when attempting to move a node into one of its own descendants,
/// which would create a cycle in the tree.
///
/// Requirement: 4.4
final class CircularMove extends MindmapException {
  final String nodeId;
  final String targetId;

  const CircularMove({required this.nodeId, required this.targetId});

  @override
  String toString() =>
      'CircularMove: cannot move node $nodeId into its descendant $targetId';
}

/// Thrown when attempting to delete the last remaining mindmap for a subject.
///
/// Requirement: 10.6
final class CannotDeleteLastMindmap extends MindmapException {
  final int subjectId;
  final String mindmapId;

  const CannotDeleteLastMindmap({
    required this.subjectId,
    required this.mindmapId,
  });

  @override
  String toString() =>
      'CannotDeleteLastMindmap: mindmap $mindmapId is the last mindmap '
      'for subject $subjectId';
}
