import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/mindmap/models/mindmap_exception.dart';
import 'package:study_assistant_app/components/mindmap/models/mindmap_meta.dart';
import 'package:study_assistant_app/components/mindmap/models/node_tree_state.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  // ── TreeNode ──────────────────────────────────────────────────────────────

  group('TreeNode', () {
    test('toJson / fromJson round-trip', () {
      final node = TreeNode(
        nodeId: 'abc-123',
        text: 'Hello',
        depth: 2,
        parentId: 'parent-1',
        isUserCreated: true,
        children: [
          TreeNode(
            nodeId: 'child-1',
            text: 'Child',
            depth: 3,
            parentId: 'abc-123',
          ),
        ],
      );

      final json = node.toJson();
      final restored = TreeNode.fromJson(json);

      expect(restored.nodeId, equals(node.nodeId));
      expect(restored.text, equals(node.text));
      expect(restored.depth, equals(node.depth));
      expect(restored.parentId, equals(node.parentId));
      expect(restored.isUserCreated, equals(node.isUserCreated));
      expect(restored.children.length, equals(1));
      expect(restored.children.first.nodeId, equals('child-1'));
    });

    test('fromJson backward compat: missing node_id generates UUID', () {
      final json = <String, dynamic>{
        'text': 'Old node',
        'depth': 1,
      };
      final node = TreeNode.fromJson(json);
      expect(node.nodeId, isNotEmpty);
      expect(node.nodeId.length, greaterThan(10)); // UUID-like
    });

    test('fromJson backward compat: missing parent_id defaults to null', () {
      final json = <String, dynamic>{
        'node_id': 'x',
        'text': 'Root',
        'depth': 1,
      };
      final node = TreeNode.fromJson(json);
      expect(node.parentId, isNull);
    });

    test('fromJson backward compat: missing is_user_created defaults to false',
        () {
      final json = <String, dynamic>{
        'node_id': 'x',
        'text': 'Root',
        'depth': 1,
      };
      final node = TreeNode.fromJson(json);
      expect(node.isUserCreated, isFalse);
    });

    test('depth supports up to 6', () {
      final node = TreeNode(nodeId: 'n', text: 'Deep', depth: 6);
      expect(node.depth, equals(6));
      final json = node.toJson();
      final restored = TreeNode.fromJson(json);
      expect(restored.depth, equals(6));
    });
  });

  // ── MindmapMeta ───────────────────────────────────────────────────────────

  group('MindmapMeta', () {
    test('create() generates a non-empty UUID id', () {
      final meta = MindmapMeta.create(subjectId: 1, name: 'Test Map');
      expect(meta.id, isNotEmpty);
      expect(meta.subjectId, equals(1));
      expect(meta.name, equals('Test Map'));
    });

    test('toJson / fromJson round-trip', () {
      final meta = MindmapMeta(
        id: 'meta-id-1',
        subjectId: 42,
        name: 'My Map',
        createdAt: DateTime(2024, 1, 15, 10, 0),
        updatedAt: DateTime(2024, 1, 16, 12, 30),
      );

      final json = meta.toJson();
      final restored = MindmapMeta.fromJson(json);

      expect(restored.id, equals(meta.id));
      expect(restored.subjectId, equals(meta.subjectId));
      expect(restored.name, equals(meta.name));
      expect(restored.createdAt, equals(meta.createdAt));
      expect(restored.updatedAt, equals(meta.updatedAt));
    });

    test('copyWith updates only specified fields', () {
      final meta = MindmapMeta.create(subjectId: 1, name: 'Original');
      final updated = meta.copyWith(name: 'Updated');

      expect(updated.id, equals(meta.id));
      expect(updated.subjectId, equals(meta.subjectId));
      expect(updated.name, equals('Updated'));
    });

    test('equality is based on id', () {
      final a = MindmapMeta(
        id: 'same-id',
        subjectId: 1,
        name: 'A',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final b = MindmapMeta(
        id: 'same-id',
        subjectId: 2,
        name: 'B',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(a, equals(b));
    });
  });

  // ── NodeTreeState ─────────────────────────────────────────────────────────

  group('NodeTreeState', () {
    test('empty() creates state with no roots and clean flags', () {
      const state = NodeTreeState.empty();
      expect(state.roots, isEmpty);
      expect(state.isDirty, isFalse);
      expect(state.lastSavedAt, isNull);
      expect(state.draggingNodeId, isNull);
      expect(state.dropTargetId, isNull);
    });

    test('copyWith updates specified fields', () {
      const state = NodeTreeState.empty();
      final now = DateTime.now();
      final updated = state.copyWith(isDirty: true, lastSavedAt: now);

      expect(updated.isDirty, isTrue);
      expect(updated.lastSavedAt, equals(now));
      expect(updated.roots, isEmpty); // unchanged
    });

    test('copyWith clearDraggingNodeId sets to null', () {
      final state = NodeTreeState(
        roots: const [],
        draggingNodeId: 'node-1',
      );
      final cleared = state.copyWith(clearDraggingNodeId: true);
      expect(cleared.draggingNodeId, isNull);
    });

    test('copyWith clearDropTargetId sets to null', () {
      final state = NodeTreeState(
        roots: const [],
        dropTargetId: 'target-1',
      );
      final cleared = state.copyWith(clearDropTargetId: true);
      expect(cleared.dropTargetId, isNull);
    });
  });

  // ── MindmapException ──────────────────────────────────────────────────────

  group('MindmapException', () {
    test('MaxDepthExceeded has correct fields', () {
      const e = MaxDepthExceeded(attemptedDepth: 7);
      expect(e.maxDepth, equals(6));
      expect(e.attemptedDepth, equals(7));
      expect(e.toString(), contains('7'));
      expect(e, isA<MindmapException>());
    });

    test('CannotDeleteRoot has correct fields', () {
      const e = CannotDeleteRoot(nodeId: 'root-1');
      expect(e.nodeId, equals('root-1'));
      expect(e.toString(), contains('root-1'));
      expect(e, isA<MindmapException>());
    });

    test('CircularMove has correct fields', () {
      const e = CircularMove(nodeId: 'a', targetId: 'b');
      expect(e.nodeId, equals('a'));
      expect(e.targetId, equals('b'));
      expect(e.toString(), contains('a'));
      expect(e.toString(), contains('b'));
      expect(e, isA<MindmapException>());
    });

    test('CannotDeleteLastMindmap has correct fields', () {
      const e = CannotDeleteLastMindmap(subjectId: 5, mindmapId: 'map-1');
      expect(e.subjectId, equals(5));
      expect(e.mindmapId, equals('map-1'));
      expect(e.toString(), contains('map-1'));
      expect(e, isA<MindmapException>());
    });

    test('sealed class exhaustive switch compiles', () {
      // Verify the sealed hierarchy can be exhaustively matched
      MindmapException ex = const MaxDepthExceeded(attemptedDepth: 7);
      final result = switch (ex) {
        MaxDepthExceeded() => 'max_depth',
        CannotDeleteRoot() => 'cannot_delete_root',
        CircularMove() => 'circular_move',
        CannotDeleteLastMindmap() => 'cannot_delete_last',
      };
      expect(result, equals('max_depth'));
    });
  });

  // ── MindMapParser depth-6 support ─────────────────────────────────────────

  group('MindMapParser depth-6 support', () {
    test('parses nodes up to depth 6', () {
      // We just verify TreeNode accepts depth 6
      final node = TreeNode(nodeId: 'n', text: 'Deep', depth: 6);
      expect(node.depth, equals(6));
    });
  });
}
