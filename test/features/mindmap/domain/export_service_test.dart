import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/mindmap/domain/export_service.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  group('ExportService.toMarkdown', () {
    // Helper to build a leaf node at a given depth.
    TreeNode leaf(String text, int depth, {String? parentId}) => TreeNode(
          nodeId: 'id-$text',
          text: text,
          depth: depth,
          parentId: parentId,
        );

    test('single node outputs "# Root"', () {
      final roots = [leaf('Root', 1)];
      expect(ExportService.toMarkdown(roots), '# Root\n');
    });

    test('depth 2 node outputs "## Child"', () {
      final roots = [leaf('Child', 2)];
      expect(ExportService.toMarkdown(roots), '## Child\n');
    });

    test('depth equals number of # characters', () {
      for (var depth = 1; depth <= 6; depth++) {
        final node = leaf('Node', depth);
        final md = ExportService.toMarkdown([node]);
        final hashes = md.split(' ').first;
        expect(hashes.length, depth,
            reason: 'depth $depth should produce $depth # chars');
      }
    });

    test('multi-level tree outputs correct # counts', () {
      // Build: Root(1) â†?Child(2) â†?Grandchild(3)
      final grandchild = TreeNode(
        nodeId: 'gc',
        text: 'Grandchild',
        depth: 3,
        parentId: 'c',
      );
      final child = TreeNode(
        nodeId: 'c',
        text: 'Child',
        depth: 2,
        parentId: 'r',
        children: [grandchild],
      );
      final root = TreeNode(
        nodeId: 'r',
        text: 'Root',
        depth: 1,
        children: [child],
      );

      final md = ExportService.toMarkdown([root]);
      expect(md, '# Root\n## Child\n### Grandchild\n');
    });

    test('pre-order traversal: parent appears before children', () {
      final child1 = TreeNode(
        nodeId: 'c1',
        text: 'Child1',
        depth: 2,
        parentId: 'r',
      );
      final child2 = TreeNode(
        nodeId: 'c2',
        text: 'Child2',
        depth: 2,
        parentId: 'r',
      );
      final root = TreeNode(
        nodeId: 'r',
        text: 'Root',
        depth: 1,
        children: [child1, child2],
      );

      final lines = ExportService.toMarkdown([root])
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();

      expect(lines[0], '# Root');
      expect(lines[1], '## Child1');
      expect(lines[2], '## Child2');
    });

    test('empty roots returns empty string', () {
      expect(ExportService.toMarkdown([]), '');
    });

    test('multiple root nodes are all serialized', () {
      final roots = [leaf('A', 1), leaf('B', 1), leaf('C', 1)];
      final md = ExportService.toMarkdown(roots);
      expect(md, '# A\n# B\n# C\n');
    });
  });
}
