import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/mindmap_library.dart';

// ── Layout constants ──────────────────────────────────────────────────────────

const double _rootHPad = 20;
const double _rootVPad = 12;
const double _nodeHPad = 12;
const double _nodeVPad = 8;
const double _nodeMinWidth = 80;
const double _nodeMaxWidth = 150;
const double _rootMaxWidth = 180;
const double _levelGapX = 80; // horizontal gap between levels
const double _siblingGapY = 14; // vertical gap between siblings
const double _fontSize = 12;
const double _rootFontSize = 14;
const double _iconSize = 13;

// ── NodeLayout ────────────────────────────────────────────────────────────────

/// Computed layout info for a single node.
class NodeLayout {
  final TreeNode node;
  final Rect rect;
  final bool hasLecture;
  final String? displayText; // 带序号的显示文本，null 时用 node.text

  const NodeLayout({
    required this.node,
    required this.rect,
    required this.hasLecture,
    this.displayText,
  });
}

// ── Layout pass ───────────────────────────────────────────────────────────────

/// Measures the height of a subtree rooted at [node] (including the node itself).
double _subtreeHeight(TreeNode node) {
  final nodeH = _nodeVPad * 2 + _fontSize + 4;
  if (!node.isExpanded || node.children.isEmpty) return nodeH;
  double childrenH = 0;
  for (int i = 0; i < node.children.length; i++) {
    childrenH += _subtreeHeight(node.children[i]);
    if (i < node.children.length - 1) childrenH += _siblingGapY;
  }
  return math.max(nodeH, childrenH);
}

/// Measures the width of a node box (not including children).
double _measureNodeWidth(String text, TextStyle style, {bool isRoot = false}) {
  final maxW = isRoot ? _rootMaxWidth : _nodeMaxWidth;
  final hPad = isRoot ? _rootHPad : _nodeHPad;
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxW - hPad * 2);
  return (tp.width + hPad * 2).clamp(_nodeMinWidth, maxW);
}

/// Recursively lays out a subtree expanding to the LEFT.
/// [rightEdge] is the right edge of the parent node.
/// [centerY] is the vertical center the subtree should be aligned to.
/// Returns the list of NodeLayouts for this subtree (node + all descendants).
List<NodeLayout> _layoutSubtreeLeft({
  required TreeNode node,
  required double rightEdge,
  required double centerY,
  required Set<String> lectureNodeIds,
  required TextStyle textStyle,
  required String numberPrefix,
}) {
  final result = <NodeLayout>[];
  final nodeH = _nodeVPad * 2 + _fontSize + 4;
  // 宽度只按原始文字测量，不含序号
  final nodeW = _measureNodeWidth(node.text, textStyle);

  final nodeLeft = rightEdge - _levelGapX - nodeW;
  final nodeTop = centerY - nodeH / 2;
  final nodeRect = Rect.fromLTWH(nodeLeft, nodeTop, nodeW, nodeH);

  result.add(NodeLayout(
    node: node,
    rect: nodeRect,
    hasLecture: lectureNodeIds.contains(node.nodeId),
    displayText: numberPrefix.isEmpty ? null : numberPrefix, // 只存序号，文字单独绘制
  ));

  if (node.isExpanded && node.children.isNotEmpty) {
    // Compute total children height
    double totalH = 0;
    for (int i = 0; i < node.children.length; i++) {
      totalH += _subtreeHeight(node.children[i]);
      if (i < node.children.length - 1) totalH += _siblingGapY;
    }

    double childY = centerY - totalH / 2;
    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      final childH = _subtreeHeight(child);
      final childCenterY = childY + childH / 2;
      final childNumber = numberPrefix.isEmpty
          ? '${i + 1}'
          : '$numberPrefix.${i + 1}';
      result.addAll(_layoutSubtreeLeft(
        node: child,
        rightEdge: nodeLeft, // children expand further left
        centerY: childCenterY,
        lectureNodeIds: lectureNodeIds,
        textStyle: textStyle,
        numberPrefix: childNumber,
      ));
      childY += childH + _siblingGapY;
    }
  }

  return result;
}

/// Recursively lays out a subtree expanding to the RIGHT.
/// [leftEdge] is the left edge of the parent node.
/// [centerY] is the vertical center the subtree should be aligned to.
List<NodeLayout> _layoutSubtreeRight({
  required TreeNode node,
  required double leftEdge,
  required double centerY,
  required Set<String> lectureNodeIds,
  required TextStyle textStyle,
  required String numberPrefix,
}) {
  final result = <NodeLayout>[];
  final nodeH = _nodeVPad * 2 + _fontSize + 4;
  // 宽度只按原始文字测量，不含序号
  final nodeW = _measureNodeWidth(node.text, textStyle);

  final nodeLeft = leftEdge + _levelGapX;
  final nodeTop = centerY - nodeH / 2;
  final nodeRect = Rect.fromLTWH(nodeLeft, nodeTop, nodeW, nodeH);

  result.add(NodeLayout(
    node: node,
    rect: nodeRect,
    hasLecture: lectureNodeIds.contains(node.nodeId),
    displayText: numberPrefix.isEmpty ? null : numberPrefix, // 只存序号
  ));

  if (node.isExpanded && node.children.isNotEmpty) {
    double totalH = 0;
    for (int i = 0; i < node.children.length; i++) {
      totalH += _subtreeHeight(node.children[i]);
      if (i < node.children.length - 1) totalH += _siblingGapY;
    }

    double childY = centerY - totalH / 2;
    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      final childH = _subtreeHeight(child);
      final childCenterY = childY + childH / 2;
      final childNumber = numberPrefix.isEmpty
          ? '${i + 1}'
          : '$numberPrefix.${i + 1}';
      result.addAll(_layoutSubtreeRight(
        node: child,
        leftEdge: nodeLeft + nodeW, // children expand further right
        centerY: childCenterY,
        lectureNodeIds: lectureNodeIds,
        textStyle: textStyle,
        numberPrefix: childNumber,
      ));
      childY += childH + _siblingGapY;
    }
  }

  return result;
}

/// Computes [NodeLayout] for every visible node in the tree.
/// Implements a radial (left-right split) layout:
///   - Root node at center
///   - First half of level-1 children on the left, second half on the right
///   - Each subtree expands outward (left→left, right→right)
List<NodeLayout> computeLayout({
  required List<TreeNode> roots,
  required Set<String> lectureNodeIds,
  required TextStyle textStyle,
}) {
  if (roots.isEmpty) return [];

  final result = <NodeLayout>[];

  // We support a single root (typical case). If multiple roots exist,
  // treat them all as right-side nodes with a virtual center.
  final TreeNode root = roots.first;
  final rootStyle = textStyle.copyWith(
    fontSize: _rootFontSize,
    fontWeight: FontWeight.bold,
  );
  final rootNodeH = _rootVPad * 2 + _rootFontSize + 4;
  final rootNodeW = _measureNodeWidth(root.text, rootStyle, isRoot: true);

  final children = root.isExpanded ? root.children : <TreeNode>[];
  final int total = children.length;
  final int leftCount = total ~/ 2;
  // rightCount intentionally unused; rightChildren.length serves the same purpose
  final leftChildren = children.sublist(0, leftCount);
  final rightChildren = children.sublist(leftCount);

  // Compute total height needed for left and right groups
  double groupHeight(List<TreeNode> nodes) {
    if (nodes.isEmpty) return rootNodeH;
    double h = 0;
    for (int i = 0; i < nodes.length; i++) {
      h += _subtreeHeight(nodes[i]);
      if (i < nodes.length - 1) h += _siblingGapY;
    }
    return h;
  }

  final leftGroupH = groupHeight(leftChildren);
  final rightGroupH = groupHeight(rightChildren);
  math.max(leftGroupH, rightGroupH); // total height (unused directly)

  // Root is placed at a logical origin; we'll shift everything later via
  // computeCanvasSize + InteractiveViewer. Use (0,0) as root center.
  // We'll compute absolute coords and then shift to positive space at the end.

  // Root center
  const double rootCX = 0;
  const double rootCY = 0;

  // Root rect
  final rootRect = Rect.fromCenter(
    center: const Offset(rootCX, rootCY),
    width: rootNodeW,
    height: rootNodeH,
  );
  result.add(NodeLayout(
    node: root,
    rect: rootRect,
    hasLecture: lectureNodeIds.contains(root.nodeId),
    displayText: null,
  ));

  // Layout left children (expand leftward from root's left edge)
  if (leftChildren.isNotEmpty) {
    double childY = rootCY - leftGroupH / 2;
    for (int i = 0; i < leftChildren.length; i++) {
      final child = leftChildren[i];
      final childH = _subtreeHeight(child);
      final childCenterY = childY + childH / 2;
      final number = '${i + 1}';
      result.addAll(_layoutSubtreeLeft(
        node: child,
        rightEdge: rootRect.left,
        centerY: childCenterY,
        lectureNodeIds: lectureNodeIds,
        textStyle: textStyle,
        numberPrefix: number,
      ));
      childY += childH + _siblingGapY;
    }
  }

  // Layout right children (expand rightward from root's right edge)
  if (rightChildren.isNotEmpty) {
    double childY = rootCY - rightGroupH / 2;
    for (int i = 0; i < rightChildren.length; i++) {
      final child = rightChildren[i];
      final childH = _subtreeHeight(child);
      final childCenterY = childY + childH / 2;
      // Right children numbering continues from leftCount+1
      final number = '${leftCount + i + 1}';
      result.addAll(_layoutSubtreeRight(
        node: child,
        leftEdge: rootRect.right,
        centerY: childCenterY,
        lectureNodeIds: lectureNodeIds,
        textStyle: textStyle,
        numberPrefix: number,
      ));
      childY += childH + _siblingGapY;
    }
  }

  // Shift all rects so minimum x/y is at (padding, padding)
  const double padding = 32;
  double minX = double.infinity;
  double minY = double.infinity;
  for (final l in result) {
    if (l.rect.left < minX) minX = l.rect.left;
    if (l.rect.top < minY) minY = l.rect.top;
  }
  final dx = padding - minX;
  final dy = padding - minY;

  return result.map((l) => NodeLayout(
    node: l.node,
    rect: l.rect.translate(dx, dy),
    hasLecture: l.hasLecture,
    displayText: l.displayText,
  )).toList();
}

// ── NodeState enum ────────────────────────────────────────────────────────────

enum NodeDisplayState { normal, lit, halfLit, userCreated }

NodeDisplayState resolveNodeState({
  required TreeNode node,
  required Map<String, bool> states,
}) {
  if (states[node.nodeId] == true) return NodeDisplayState.lit;
  if (node.isUserCreated) return NodeDisplayState.userCreated;
  // Half-lit: all direct children are lit
  if (node.children.isNotEmpty &&
      node.children.every((c) => states[c.nodeId] == true)) {
    return NodeDisplayState.halfLit;
  }
  return NodeDisplayState.normal;
}

// ── MindMapPainter ────────────────────────────────────────────────────────────

class MindMapPainter extends CustomPainter {
  final List<NodeLayout> layouts;
  final Map<String, bool> nodeStates;
  final ColorScheme colorScheme;

  MindMapPainter({
    required this.layouts,
    required this.nodeStates,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Build a map for quick lookup
    final layoutMap = {for (final l in layouts) l.node.nodeId: l};

    // Draw connections first (behind nodes)
    final linePaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final layout in layouts) {
      if (layout.node.parentId != null) {
        final parentLayout = layoutMap[layout.node.parentId];
        if (parentLayout != null) {
          _drawBezier(canvas, linePaint, parentLayout.rect, layout.rect);
        }
      }
    }

    // Draw nodes
    for (final layout in layouts) {
      _drawNode(canvas, layout);
    }
  }

  void _drawBezier(Canvas canvas, Paint paint, Rect parent, Rect child) {
    // Determine if child is to the left or right of parent
    final parentCX = parent.center.dx;
    final childCX = child.center.dx;

    final Offset start;
    final Offset end;

    if (childCX < parentCX) {
      // Child is to the left: connect from parent's left edge to child's right edge
      start = Offset(parent.left, parent.center.dy);
      end = Offset(child.right, child.center.dy);
    } else {
      // Child is to the right: connect from parent's right edge to child's left edge
      start = Offset(parent.right, parent.center.dy);
      end = Offset(child.left, child.center.dy);
    }

    final midX = (start.dx + end.dx) / 2;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  void _drawNode(Canvas canvas, NodeLayout layout) {
    final node = layout.node;
    final rect = layout.rect;
    final state = resolveNodeState(node: node, states: nodeStates);
    final isRoot = node.parentId == null;

    // Colors
    Color bgColor;
    Color textColor;
    Color? borderColor;
    bool dashedBorder = false;

    if (isRoot) {
      bgColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
      borderColor = null;
    } else {
      switch (state) {
        case NodeDisplayState.lit:
          bgColor = colorScheme.primary;
          textColor = colorScheme.onPrimary;
          borderColor = null;
        case NodeDisplayState.halfLit:
          bgColor = colorScheme.primaryContainer;
          textColor = colorScheme.onPrimaryContainer;
          borderColor = null;
        case NodeDisplayState.userCreated:
          bgColor = colorScheme.tertiaryContainer;
          textColor = colorScheme.onTertiaryContainer;
          borderColor = colorScheme.tertiary;
          dashedBorder = true;
        case NodeDisplayState.normal:
          bgColor = colorScheme.surfaceContainerHigh;
          textColor = colorScheme.onSurface;
          borderColor = colorScheme.outlineVariant;
      }
    }

    final radius = isRoot ? const Radius.circular(12) : const Radius.circular(8);
    final rRect = RRect.fromRectAndRadius(rect, radius);

    // Background
    canvas.drawRRect(rRect, Paint()..color = bgColor);

    // Border
    if (borderColor != null) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      if (dashedBorder) {
        _drawDashedRRect(canvas, rRect, borderPaint);
      } else {
        canvas.drawRRect(rRect, borderPaint);
      }
    }

    // 节点内只显示原始文字
    final fontSize = isRoot ? _rootFontSize : _fontSize;
    final hPad = isRoot ? _rootHPad : _nodeHPad;

    // 序号显示在节点上方（小字，灰色）
    if (!isRoot && layout.displayText != null) {
      final numPainter = TextPainter(
        text: TextSpan(
          text: layout.displayText,
          style: TextStyle(
            fontSize: 9,
            color: textColor.withValues(alpha: 0.55),
            fontWeight: FontWeight.w400,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width);
      numPainter.paint(
        canvas,
        Offset(rect.left + hPad, rect.top - numPainter.height - 1),
      );
    }

    // 节点内只显示原始文字
    final tp = TextPainter(
      text: TextSpan(
        text: node.text,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: isRoot ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - hPad * 2 - (layout.hasLecture ? _iconSize + 4 : 0));

    final textX = rect.left + hPad;
    final textY = rect.top + (rect.height - tp.height) / 2;
    tp.paint(canvas, Offset(textX, textY));

    // 📖 icon for nodes with lectures
    if (layout.hasLecture) {
      final iconPainter = TextPainter(
        text: const TextSpan(
          text: '📖',
          style: TextStyle(fontSize: _iconSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(rect.right - hPad - _iconSize, rect.top + 4),
      );
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rRect, Paint paint) {
    final path = Path()..addRRect(rRect);
    final dashPath = _createDashedPath(path, dashLength: 6, gapLength: 4);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source,
      {double dashLength = 6, double gapLength = 4}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (draw) {
          result.addPath(
            metric.extractPath(
                distance, math.min(distance + len, metric.length)),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(MindMapPainter oldDelegate) =>
      oldDelegate.layouts != layouts ||
      oldDelegate.nodeStates != nodeStates ||
      oldDelegate.colorScheme != colorScheme;

  /// Hit-test: returns the NodeLayout at [position], or null.
  static NodeLayout? nodeAt(List<NodeLayout> layouts, Offset position) {
    for (final layout in layouts) {
      if (layout.rect.contains(position)) return layout;
    }
    return null;
  }
}

/// Compute the bounding size needed to display all layouts.
Size computeCanvasSize(List<NodeLayout> layouts) {
  if (layouts.isEmpty) return const Size(400, 300);
  double maxX = 0, maxY = 0;
  for (final l in layouts) {
    if (l.rect.right > maxX) maxX = l.rect.right;
    if (l.rect.bottom > maxY) maxY = l.rect.bottom;
  }
  return Size(maxX + 32, maxY + 32);
}
