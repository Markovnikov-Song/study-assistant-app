import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/features/library/lecture/export_book_dialog.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

TreeNode _node(
  String id,
  String text, {
  int depth = 1,
  List<TreeNode> children = const [],
}) =>
    TreeNode(nodeId: id, text: text, depth: depth, children: children);

/// Pumps [ExportBookDialog] with a 800×900 surface so the SegmentedButton row
/// does not overflow the default 800×600 test canvas.
Future<void> _pumpDialog(
  WidgetTester tester, {
  required List<TreeNode> nodes,
  required Set<String> hasLectureNodeIds,
  int sessionId = 1,
  String sessionTitle = 'Test Session',
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ExportBookDialog(
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            nodes: nodes,
            hasLectureNodeIds: hasLectureNodeIds,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  final nodeA = _node('A', 'Node A');
  final nodeB = _node('B', 'Node B');
  final nodeC = _node('C', 'Node C');
  final flatNodes = [nodeA, nodeB, nodeC];
  final allIds = {'A', 'B', 'C'};

  // ── 1. Select-all / select-none button behavior ────────────────────────────
  // Requirements: 1.5
  group('select-all / select-none buttons', () {
    testWidgets('select-none deselects all nodes', (tester) async {
      await _pumpDialog(tester, nodes: flatNodes, hasLectureNodeIds: allIds);

      expect(find.text('已选 3 个节点'), findsOneWidget);

      await tester.tap(find.text('全不选'));
      await tester.pump();

      expect(find.text('已选 0 个节点'), findsOneWidget);
    });

    testWidgets('select-all re-selects all nodes after deselecting', (tester) async {
      await _pumpDialog(tester, nodes: flatNodes, hasLectureNodeIds: allIds);

      await tester.tap(find.text('全不选'));
      await tester.pump();
      expect(find.text('已选 0 个节点'), findsOneWidget);

      await tester.tap(find.text('全选'));
      await tester.pump();

      expect(find.text('已选 3 个节点'), findsOneWidget);
    });
  });

  // ── 2. Parent node check cascades to children ──────────────────────────────
  // Requirements: 1.3
  group('parent node cascade', () {
    testWidgets('unchecking parent unchecks all children', (tester) async {
      final child1 = _node('child1', 'Child 1', depth: 2);
      final child2 = _node('child2', 'Child 2', depth: 2);
      final parent = _node('parent', 'Parent', depth: 1, children: [child1, child2]);

      await _pumpDialog(
        tester,
        nodes: [parent],
        hasLectureNodeIds: {'parent', 'child1', 'child2'},
      );

      // All 3 selected initially
      expect(find.text('已选 3 个节点'), findsOneWidget);

      // Tap the parent row — all descendants should deselect
      await tester.tap(find.text('Parent'));
      await tester.pump();

      expect(find.text('已选 0 个节点'), findsOneWidget);
    });

    testWidgets('checking parent checks all children', (tester) async {
      final child1 = _node('child1', 'Child 1', depth: 2);
      final child2 = _node('child2', 'Child 2', depth: 2);
      final parent = _node('parent', 'Parent', depth: 1, children: [child1, child2]);

      await _pumpDialog(
        tester,
        nodes: [parent],
        hasLectureNodeIds: {'parent', 'child1', 'child2'},
      );

      // Deselect all first
      await tester.tap(find.text('全不选'));
      await tester.pump();
      expect(find.text('已选 0 个节点'), findsOneWidget);

      // Tap parent row to select it and all descendants
      await tester.tap(find.text('Parent'));
      await tester.pump();

      expect(find.text('已选 3 个节点'), findsOneWidget);
    });
  });

  // ── 3. Export button disabled when no nodes selected ──────────────────────
  // Requirements: 1.6
  group('export button disabled state', () {
    testWidgets('export button is enabled when nodes are selected', (tester) async {
      await _pumpDialog(tester, nodes: flatNodes, hasLectureNodeIds: allIds);

      final exportBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '导出'),
      );
      expect(exportBtn.onPressed, isNotNull);
    });

    testWidgets('export button is disabled when no nodes selected', (tester) async {
      await _pumpDialog(tester, nodes: flatNodes, hasLectureNodeIds: allIds);

      await tester.tap(find.text('全不选'));
      await tester.pump();

      final exportBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '导出'),
      );
      expect(exportBtn.onPressed, isNull);
    });

    testWidgets('validation text shown when no nodes selected', (tester) async {
      await _pumpDialog(tester, nodes: flatNodes, hasLectureNodeIds: allIds);

      await tester.tap(find.text('全不选'));
      await tester.pump();

      expect(find.text('请至少选择一个节点'), findsOneWidget);
    });

    testWidgets('validation text hidden when at least one node selected', (tester) async {
      await _pumpDialog(tester, nodes: flatNodes, hasLectureNodeIds: allIds);

      // All nodes selected by default — no validation text
      expect(find.text('请至少选择一个节点'), findsNothing);
    });
  });

  // ── 4. Warning text shown when selected nodes include nodes without lectures
  // Requirements: 2.1, 2.2
  group('no-lecture warning', () {
    testWidgets('warning shown when selected nodes include nodes without lectures', (tester) async {
      // nodeA and nodeB have lectures; nodeC does not
      await _pumpDialog(
        tester,
        nodes: flatNodes,
        hasLectureNodeIds: {'A', 'B'},
      );

      expect(find.textContaining('暂无讲义，导出时将跳过'), findsOneWidget);
    });

    testWidgets('warning shows correct count of nodes without lectures', (tester) async {
      // Only nodeA has a lecture; B and C do not
      await _pumpDialog(
        tester,
        nodes: flatNodes,
        hasLectureNodeIds: {'A'},
      );

      expect(find.text('2 个节点暂无讲义，导出时将跳过'), findsOneWidget);
    });

    testWidgets('warning hidden when all selected nodes have lectures', (tester) async {
      await _pumpDialog(tester, nodes: flatNodes, hasLectureNodeIds: allIds);

      expect(find.textContaining('暂无讲义，导出时将跳过'), findsNothing);
    });

    testWidgets('warning disappears after deselecting nodes without lectures', (tester) async {
      // nodeC has no lecture
      await _pumpDialog(
        tester,
        nodes: flatNodes,
        hasLectureNodeIds: {'A', 'B'},
      );

      // Warning visible initially (C is selected but has no lecture)
      expect(find.textContaining('暂无讲义，导出时将跳过'), findsOneWidget);

      // Deselect nodeC by tapping its row
      await tester.tap(find.text('Node C'));
      await tester.pump();

      expect(find.textContaining('暂无讲义，导出时将跳过'), findsNothing);
    });
  });
}
