import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/mindmap/domain/node_tree_editor.dart';
import 'package:study_assistant_app/components/mindmap/models/mindmap_exception.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Build a simple tree:
///   root (depth 1)
///     ├── child1 (depth 2)
///     �?    └── grandchild (depth 3)
///     └── child2 (depth 2)
NodeTreeEditor _buildEditor() {
  final grandchild = TreeNode(
    nodeId: 'grandchild',
    text: 'Grandchild',
    depth: 3,
    parentId: 'child1',
  );
  final child1 = TreeNode(
    nodeId: 'child1',
    text: 'Child 1',
    depth: 2,
    parentId: 'root',
    children: [grandchild],
  );
  final child2 = TreeNode(
    nodeId: 'child2',
    text: 'Child 2',
    depth: 2,
    parentId: 'root',
  );
  final root = TreeNode(
    nodeId: 'root',
    text: 'Root',
    depth: 1,
    children: [child1, child2],
  );
  return NodeTreeEditor([root]);
}

void main() {
  // ── addChild ──────────────────────────────────────────────────────────────

  group('addChild', () {
    test('adds a child node under the given parent', () {
      final editor = _buildEditor();
      final newNode = editor.addChild('root', 'New Child');

      expect(newNode, isNotNull);
      expect(newNode!.text, equals('New Child'));
      expect(newNode.depth, equals(2));
      expect(newNode.parentId, equals('root'));

      final root = editor.roots.first;
      expect(root.children.length, equals(3));
      expect(root.children.last.nodeId, equals(newNode.nodeId));
    });

    test('returns null for blank text (spaces only)', () {
      final editor = _buildEditor();
      final result = editor.addChild('root', '   ');
      expect(result, isNull);
      expect(editor.roots.first.children.length, equals(2)); // unchanged
    });

    test('returns null for empty string', () {
      final editor = _buildEditor();
      final result = editor.addChild('root', '');
      expect(result, isNull);
    });

    test('throws MaxDepthExceeded when parent is at depth 6', () {
      // Build a chain: depth 1 �?2 �?3 �?4 �?5 �?6
      TreeNode buildChain(int depth, String id) {
        if (depth == 6) {
          return TreeNode(nodeId: id, text: 'D$depth', depth: depth);
        }
        final childId = '${id}_c';
        return TreeNode(
          nodeId: id,
          text: 'D$depth',
          depth: depth,
          children: [buildChain(depth + 1, childId)],
        );
      }

      final root = buildChain(1, 'n1');
      final editor = NodeTreeEditor([root]);

      // Find the depth-6 node
      TreeNode? findDepth6(TreeNode n) {
        if (n.depth == 6) return n;
        for (final c in n.children) {
          final found = findDepth6(c);
          if (found != null) return found;
        }
        return null;
      }

      final deepNode = findDepth6(root)!;
      expect(
        () => editor.addChild(deepNode.nodeId, 'Too Deep'),
        throwsA(isA<MaxDepthExceeded>()),
      );
    });

    test('MaxDepthExceeded carries correct attemptedDepth', () {
      final d6 = TreeNode(nodeId: 'd6', text: 'D6', depth: 6);
      final d5 = TreeNode(
          nodeId: 'd5', text: 'D5', depth: 5, children: [d6]);
      final editor = NodeTreeEditor([
        TreeNode(nodeId: 'r', text: 'R', depth: 1, children: [d5])
      ]);

      try {
        editor.addChild('d6', 'X');
        fail('Expected MaxDepthExceeded');
      } on MaxDepthExceeded catch (e) {
        expect(e.attemptedDepth, equals(7));
      }
    });
  });

  // ── addSibling ────────────────────────────────────────────────────────────

  group('addSibling', () {
    test('inserts sibling immediately after the given node', () {
      final editor = _buildEditor();
      final sibling = editor.addSibling('child1', 'Sibling');

      expect(sibling, isNotNull);
      expect(sibling!.depth, equals(2));
      expect(sibling.parentId, equals('root'));

      final children = editor.roots.first.children;
      expect(children.length, equals(3));
      // child1 is at index 0, sibling should be at index 1
      expect(children[0].nodeId, equals('child1'));
      expect(children[1].nodeId, equals(sibling.nodeId));
      expect(children[2].nodeId, equals('child2'));
    });

    test('returns null for blank text', () {
      final editor = _buildEditor();
      final result = editor.addSibling('child1', '\t\n');
      expect(result, isNull);
      expect(editor.roots.first.children.length, equals(2));
    });
  });

  // ── updateText ────────────────────────────────────────────────────────────

  group('updateText', () {
    test('updates node text', () {
      final editor = _buildEditor();
      editor.updateText('child1', 'Updated');
      final node = editor.allNodes().firstWhere((n) => n.nodeId == 'child1');
      expect(node.text, equals('Updated'));
    });

    test('truncates text exceeding 200 characters', () {
      final editor = _buildEditor();
      final longText = 'A' * 250;
      editor.updateText('child1', longText);
      final node = editor.allNodes().firstWhere((n) => n.nodeId == 'child1');
      expect(node.text.length, equals(200));
      expect(node.text, equals('A' * 200));
    });

    test('keeps text of exactly 200 characters unchanged', () {
      final editor = _buildEditor();
      final text200 = 'B' * 200;
      editor.updateText('child1', text200);
      final node = editor.allNodes().firstWhere((n) => n.nodeId == 'child1');
      expect(node.text.length, equals(200));
    });
  });

  // ── deleteNode ────────────────────────────────────────────────────────────

  group('deleteNode', () {
    test('deletes a leaf node', () {
      final editor = _buildEditor();
      editor.deleteNode('child2');
      final ids = editor.allNodes().map((n) => n.nodeId).toList();
      expect(ids, isNot(contains('child2')));
      expect(ids, contains('child1'));
    });

    test('deletes a node and all its descendants', () {
      final editor = _buildEditor();
      editor.deleteNode('child1');
      final ids = editor.allNodes().map((n) => n.nodeId).toList();
      expect(ids, isNot(contains('child1')));
      expect(ids, isNot(contains('grandchild')));
      expect(ids, contains('root'));
      expect(ids, contains('child2'));
    });

    test('throws CannotDeleteRoot when deleting a root node', () {
      final editor = _buildEditor();
      expect(
        () => editor.deleteNode('root'),
        throwsA(isA<CannotDeleteRoot>()),
      );
    });

    test('CannotDeleteRoot carries the correct nodeId', () {
      final editor = _buildEditor();
      try {
        editor.deleteNode('root');
        fail('Expected CannotDeleteRoot');
      } on CannotDeleteRoot catch (e) {
        expect(e.nodeId, equals('root'));
      }
    });
  });

  // ── moveNode ──────────────────────────────────────────────────────────────

  group('moveNode', () {
    test('moves a node to a new parent', () {
      final editor = _buildEditor();
      // Move child2 under child1
      editor.moveNode('child2', 'child1');

      final child1 =
          editor.allNodes().firstWhere((n) => n.nodeId == 'child1');
      final child2 =
          editor.allNodes().firstWhere((n) => n.nodeId == 'child2');

      expect(child1.children.any((c) => c.nodeId == 'child2'), isTrue);
      expect(child2.parentId, equals('child1'));
      expect(child2.depth, equals(3));
      // child2 should no longer be a direct child of root
      expect(
        editor.roots.first.children.any((c) => c.nodeId == 'child2'),
        isFalse,
      );
    });

    test('throws CircularMove when target is a descendant of the node', () {
      final editor = _buildEditor();
      expect(
        () => editor.moveNode('child1', 'grandchild'),
        throwsA(isA<CircularMove>()),
      );
    });

    test('CircularMove carries correct nodeId and targetId', () {
      final editor = _buildEditor();
      try {
        editor.moveNode('child1', 'grandchild');
        fail('Expected CircularMove');
      } on CircularMove catch (e) {
        expect(e.nodeId, equals('child1'));
        expect(e.targetId, equals('grandchild'));
      }
    });

    test('tree structure is unchanged after CircularMove is thrown', () {
      final editor = _buildEditor();
      final beforeIds =
          editor.allNodes().map((n) => n.nodeId).toList();

      try {
        editor.moveNode('child1', 'grandchild');
      } on CircularMove {
        // expected
      }

      final afterIds =
          editor.allNodes().map((n) => n.nodeId).toList();
      expect(afterIds, equals(beforeIds));
    });

    test('updates depth of moved node and its descendants', () {
      final editor = _buildEditor();
      // Move child1 (depth 2, has grandchild at depth 3) under child2 (depth 2)
      editor.moveNode('child1', 'child2');

      final child1 =
          editor.allNodes().firstWhere((n) => n.nodeId == 'child1');
      final grandchild =
          editor.allNodes().firstWhere((n) => n.nodeId == 'grandchild');

      expect(child1.depth, equals(3));
      expect(grandchild.depth, equals(4));
    });
  });

  // ── isDescendant ──────────────────────────────────────────────────────────

  group('isDescendant', () {
    test('returns true for a direct child', () {
      final editor = _buildEditor();
      expect(editor.isDescendant('root', 'child1'), isTrue);
    });

    test('returns true for a grandchild', () {
      final editor = _buildEditor();
      expect(editor.isDescendant('root', 'grandchild'), isTrue);
    });

    test('returns false for a non-descendant', () {
      final editor = _buildEditor();
      expect(editor.isDescendant('child2', 'child1'), isFalse);
    });

    test('returns false when ancestorId == targetId (not self-descendant)', () {
      final editor = _buildEditor();
      expect(editor.isDescendant('root', 'root'), isFalse);
    });

    test('returns false for unknown nodeId', () {
      final editor = _buildEditor();
      expect(editor.isDescendant('root', 'nonexistent'), isFalse);
    });
  });

  // ── allNodes ──────────────────────────────────────────────────────────────

  group('allNodes', () {
    test('returns nodes in pre-order traversal', () {
      final editor = _buildEditor();
      final ids = editor.allNodes().map((n) => n.nodeId).toList();
      // Pre-order: root, child1, grandchild, child2
      expect(ids, equals(['root', 'child1', 'grandchild', 'child2']));
    });

    test('returns empty list for empty editor', () {
      final editor = NodeTreeEditor([]);
      expect(editor.allNodes(), isEmpty);
    });

    test('returns single node for single-node tree', () {
      final editor = NodeTreeEditor([
        TreeNode(nodeId: 'only', text: 'Only', depth: 1),
      ]);
      expect(editor.allNodes().length, equals(1));
    });
  });

  // ── nodeDepth ─────────────────────────────────────────────────────────────

  group('nodeDepth', () {
    test('returns correct depth for root', () {
      final editor = _buildEditor();
      expect(editor.nodeDepth('root'), equals(1));
    });

    test('returns correct depth for nested node', () {
      final editor = _buildEditor();
      expect(editor.nodeDepth('grandchild'), equals(3));
    });

    test('returns -1 for unknown nodeId', () {
      final editor = _buildEditor();
      expect(editor.nodeDepth('nonexistent'), equals(-1));
    });
  });
}
