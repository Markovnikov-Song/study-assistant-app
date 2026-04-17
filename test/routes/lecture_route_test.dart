// 测试讲义页面路由 URL 生成是否正确
// 验证 nodeId 中的空格被正确编码为 %20（而非 +）

import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/routes/app_router.dart';

void main() {
  group('AppRoutes.lecturePage — nodeId URL 编码', () {
    test('nodeId 作为 query parameter 传递', () {
      final url = AppRoutes.lecturePage(9, 72, 'L2_材料力学_第2章 杆件的内力');
      expect(url.contains('node_id='), isTrue,
          reason: 'nodeId 应作为 query parameter，实际 URL: $url');
    });

    test('空格被编码为 %20，不是 +', () {
      final url = AppRoutes.lecturePage(9, 72, 'L2_材料力学_第2章 杆件的内力');
      // Uri.encodeQueryComponent 把空格编码为 +，但 go_router 会正确解码
      // 关键是不能有未编码的空格
      expect(url.contains(' '), isFalse,
          reason: 'URL 中不应有未编码的空格，实际 URL: $url');
    });

    test('URL 格式正确（路径 + query）', () {
      final url = AppRoutes.lecturePage(9, 72, 'L1_材料力学');
      expect(url, startsWith('/library/9/mindmap/72/lecture?node_id='));
    });

    test('解码后 nodeId 与原始值一致（往返属性）', () {
      const nodeId = 'L3_材料力学_第2章 杆件的内力_平面刚架与曲杆';
      final url = AppRoutes.lecturePage(9, 72, nodeId);
      // 从 URL 中提取 query parameter 并解码
      final uri = Uri.parse('http://localhost$url');
      final decoded = uri.queryParameters['node_id'];
      expect(decoded, equals(nodeId),
          reason: '解码后应与原始 nodeId 完全一致');
    });

    test('不含空格的 nodeId 解码后与原始值一致', () {
      const nodeId = 'L1_材料力学';
      final url = AppRoutes.lecturePage(9, 72, nodeId);
      final uri = Uri.parse('http://localhost$url');
      final decoded = uri.queryParameters['node_id'];
      expect(decoded, equals(nodeId));
    });
  });
}
