import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';

void main() {
  group('Progress Calculation Tests', () {
    test('Property 10: Progress calculation integrity', () {
      // Create test nodes
      final nodes = [
        TreeNode(
          nodeId: 'L1_Introduction',
          text: 'Introduction',
          depth: 1,
          parentId: null,
          isUserCreated: false,
          children: [],
          isExpanded: true,
        ),
        TreeNode(
          nodeId: 'L2_Introduction_Section1',
          text: 'Section 1',
          depth: 2,
          parentId: 'L1_Introduction',
          isUserCreated: false,
          children: [],
          isExpanded: true,
        ),
        TreeNode(
          nodeId: 'L2_Introduction_Section2',
          text: 'Section 2',
          depth: 2,
          parentId: 'L1_Introduction',
          isUserCreated: false,
          children: [],
          isExpanded: true,
        ),
        TreeNode(
          nodeId: 'L3_Introduction_Section2_Subsection1',
          text: 'Subsection 1',
          depth: 3,
          parentId: 'L2_Introduction_Section2',
          isUserCreated: false,
          children: [],
          isExpanded: true,
        ),
      ];

      // Test case 1: No nodes lit
      final Map<String, bool> states1 = {};
      final progress1 = MindMapProgress.calculate(nodes, states1);
      expect(progress1.total, equals(4));
      expect(progress1.lit, equals(0));
      expect(progress1.percent, equals(0));

      // Test case 2: Some nodes lit
      final states2 = {
        'L1_Introduction': true,
        'L2_Introduction_Section1': true,
      };
      final progress2 = MindMapProgress.calculate(nodes, states2);
      expect(progress2.total, equals(4));
      expect(progress2.lit, equals(2));
      expect(progress2.percent, equals(50));

      // Test case 3: All nodes lit
      final states3 = {
        'L1_Introduction': true,
        'L2_Introduction_Section1': true,
        'L2_Introduction_Section2': true,
        'L3_Introduction_Section2_Subsection1': true,
      };
      final progress3 = MindMapProgress.calculate(nodes, states3);
      expect(progress3.total, equals(4));
      expect(progress3.lit, equals(4));
      expect(progress3.percent, equals(100));

      // Test case 4: Empty nodes list
      final progress4 = MindMapProgress.calculate([], {});
      expect(progress4.total, equals(0));
      expect(progress4.lit, equals(0));
      expect(progress4.percent, equals(0));
    });

    test('Progress calculation with nested nodes', () {
      // Create a tree structure
      final root = TreeNode(
        nodeId: 'root',
        text: 'Root',
        depth: 1,
        parentId: null,
        isUserCreated: false,
        children: [
          TreeNode(
            nodeId: 'child1',
            text: 'Child 1',
            depth: 2,
            parentId: 'root',
            isUserCreated: false,
            children: [
              TreeNode(
                nodeId: 'grandchild1',
                text: 'Grandchild 1',
                depth: 3,
                parentId: 'child1',
                isUserCreated: false,
                children: [],
                isExpanded: true,
              ),
            ],
            isExpanded: true,
          ),
          TreeNode(
            nodeId: 'child2',
            text: 'Child 2',
            depth: 2,
            parentId: 'root',
            isUserCreated: false,
            children: [],
            isExpanded: true,
          ),
        ],
        isExpanded: true,
      );

      // Flatten the nodes
      final allNodes = _flattenNodes([root]);
      
      // Test progress calculation
      final states = {
        'root': true,
        'child1': true,
        'grandchild1': false,
        'child2': true,
      };
      
      final progress = MindMapProgress.calculate(allNodes, states);
      expect(progress.total, equals(4));
      expect(progress.lit, equals(3));
      expect(progress.percent, equals(75));
    });

    test('Progress percent calculation edge cases', () {
      // Test with empty progress
      final empty = MindMapProgress.empty();
      expect(empty.total, equals(0));
      expect(empty.lit, equals(0));
      expect(empty.percent, equals(0));

      // Test with 1 node out of 3
      final progress1 = MindMapProgress(total: 3, lit: 1);
      expect(progress1.percent, equals(33)); // 33.33... floor to 33

      // Test with 2 nodes out of 3
      final progress2 = MindMapProgress(total: 3, lit: 2);
      expect(progress2.percent, equals(66)); // 66.66... floor to 66

      // Test with 0 total nodes
      final progress3 = MindMapProgress(total: 0, lit: 0);
      expect(progress3.percent, equals(0));
    });
  });
}

List<TreeNode> _flattenNodes(List<TreeNode> nodes) {
  final result = <TreeNode>[];
  for (final node in nodes) {
    result.add(node);
    result.addAll(_flattenNodes(node.children));
  }
  return result;
}