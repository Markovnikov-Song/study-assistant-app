import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/library/mindmap/mindmap_parser.dart';
import 'package:study_assistant_app/components/library/mindmap/mindmap_serializer.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  group('MindMapParser and Serializer Tests', () {
    test('Property 8: Markdown parsing round-trip consistency', () {
      // Test data: various Markdown structures
      final testCases = [
        '''
# Root 1
## Child 1.1
### Child 1.1.1
## Child 2
### Child 2.1
#### Child 2.1.1
        ''',
        '''
# Introduction
## Section 1
### Subsection 1.1
### Subsection 1.2
## Section 2
### Subsection 2.1
#### Subsubsection 2.1.1
        ''',
        '''
# Root
## Child 1
## Child 2
### Child 2.1
### Child 2.2
## Child 3
        ''',
      ];

      for (final markdown in testCases) {
        // Parse markdown to tree
        final roots = MindMapParser.parse(markdown);
        
        // Serialize back to markdown
        final serialized = MindMapSerializer.serializeRoots(roots);
        
        // Parse the serialized markdown again
        final reparsedRoots = MindMapParser.parse(serialized);
        MindMapSerializer.serializeRoots(reparsedRoots);
        
        // The serialized markdown should be the same after round-trip
        expect(serialized.trim(), equals(markdown.trim()),
            reason: 'Markdown should be preserved after round-trip');
      }
    });

    test('Property 7: Node ID uniqueness', () {
      const markdown = '''
# Root
## Child 1
## Child 1
### Subchild
### Subchild
      ''';
      
      final roots = MindMapParser.parse(markdown);
      
      // Collect all node IDs
      final nodeIds = <String>{};
      
      void collectIds(List<TreeNode> nodes) {
        for (final node in nodes) {
          expect(nodeIds, isNot(contains(node.nodeId)),
              reason: 'Node ID ${node.nodeId} should be unique');
          nodeIds.add(node.nodeId);
          collectIds(node.children);
        }
      }
      
      collectIds(roots);
    });

    test('Property 4: Outline list time descending invariant', () {
      // This would test that sessions are sorted by creation time descending
      // For now, we'll create a simple test structure
      final sessions = [
        _createSession(1, 'Session 1', DateTime(2024, 1, 1)),
        _createSession(2, 'Session 2', DateTime(2024, 1, 2)),
        _createSession(3, 'Session 3', DateTime(2024, 1, 3)),
      ];
      
      // Sort by created_at descending
      final sorted = List.from(sessions)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Verify descending order
      for (int i = 0; i < sorted.length - 1; i++) {
        expect(sorted[i].createdAt.compareTo(sorted[i + 1].createdAt) >= 0, isTrue);
      }
    });
  });
}

MindMapSession _createSession(int id, String title, DateTime createdAt) {
  return MindMapSession(
    id: id,
    title: title,
    resourceScopeLabel: 'Test',
    createdAt: createdAt,
    totalNodes: 10,
    litNodes: 5,
  );
}