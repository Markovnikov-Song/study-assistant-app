// lib/services/library_service.dart 的单元测试
// 使用 Dio mock 验证 HTTP 请求构造和响应解析

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:study_assistant_app/services/library_service.dart';

// ── 测试辅助 ──────────────────────────────────────────────────────────────────

LibraryService _serviceWith(DioAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  dio.httpClientAdapter = adapter;
  return LibraryService(dio: dio);
}

// ── 测试 ──────────────────────────────────────────────────────────────────────

void main() {
  group('LibraryService', () {
    late DioAdapter adapter;

    setUp(() {
      adapter = DioAdapter(dio: Dio(BaseOptions(baseUrl: 'http://localhost:8000')));
    });

    // ── 节点树 ───────────────────────────────────────────────────────────────

    group('getNodes', () {
      test('returns list of TreeNode on success', () async {
        adapter.onGet(
          '/api/library/sessions/72/nodes',
          (server) => server.reply(200, {
            'nodes': [
              {
                'node_id': 'L1_材料力学',
                'text': '材料力学',
                'depth': 1,
                'parent_id': null,
                'is_user_created': false,
                'children': [],
              },
            ],
          }),
        );

        final svc = _serviceWith(adapter);
        final nodes = await svc.getNodes(72);
        expect(nodes.length, equals(1));
        expect(nodes.first.nodeId, equals('L1_材料力学'));
        expect(nodes.first.text, equals('材料力学'));
      });

      test('returns empty list when no nodes', () async {
        adapter.onGet(
          '/api/library/sessions/72/nodes',
          (server) => server.reply(200, {'nodes': []}),
        );

        final svc = _serviceWith(adapter);
        final nodes = await svc.getNodes(72);
        expect(nodes, isEmpty);
      });
    });

    // ── 讲义 CRUD ────────────────────────────────────────────────────────────

    group('getLecture', () {
      test('returns lecture data on success', () async {
        const nodeId = 'L2_材料力学_第2章 杆件的内力';
        adapter.onGet(
          '/api/library/lectures/72',
          (server) => server.reply(200, {
            'id': 4,
            'node_id': nodeId,
            'content': {
              'blocks': [
                {'type': 'paragraph', 'text': '杆件内力是...'},
              ],
            },
            'created_at': '2026-04-17T10:00:00',
            'updated_at': '2026-04-17T10:00:00',
          }),
          queryParameters: {'node_id': nodeId},
        );

        final svc = _serviceWith(adapter);
        final data = await svc.getLecture(72, nodeId);
        expect(data['id'], equals(4));
        expect(data['node_id'], equals(nodeId));
      });

      test('throws on 404', () async {
        const nodeId = 'L1_材料力学';
        adapter.onGet(
          '/api/library/lectures/72',
          (server) => server.reply(404, {'detail': '讲义不存在'}),
          queryParameters: {'node_id': nodeId},
        );

        final svc = _serviceWith(adapter);
        expect(
          () => svc.getLecture(72, nodeId),
          throwsA(isA<DioException>()),
        );
      });
    });

    // ── 节点点亮状态 ─────────────────────────────────────────────────────────

    group('getNodeStates', () {
      test('returns map of node_id to is_lit', () async {
        adapter.onGet(
          '/api/library/sessions/72/node-states',
          (server) => server.reply(200, {
            'L1_材料力学': true,
            'L2_材料力学_第1章': false,
          }),
        );

        final svc = _serviceWith(adapter);
        final states = await svc.getNodeStates(72);
        expect(states['L1_材料力学'], isTrue);
        expect(states['L2_材料力学_第1章'], isFalse);
      });
    });

    // ── 大纲重命名 ───────────────────────────────────────────────────────────

    group('renameSession', () {
      test('sends PATCH request with title', () async {
        RequestOptions? captured;
        adapter.onPatch(
          '/api/library/sessions/72/title',
          (server) {
            server.reply(200, {'ok': true});
          },
        );

        final svc = _serviceWith(adapter);
        // 不抛出异常即为成功
        await expectLater(
          svc.renameSession(72, '新标题'),
          completes,
        );
      });
    });
  });
}
