import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_assistant_app/features/workshop/mini_app_models.dart';
import 'package:study_assistant_app/features/workshop/mini_app_providers.dart';
import 'package:study_assistant_app/features/workshop/mini_app_service.dart';
import 'package:study_assistant_app/features/workshop/workshop_page.dart';

void main() {
  testWidgets('software workshop exposes the four-action MVP flow', (
    tester,
  ) async {
    await _setDesktopSurface(tester);
    final service = _FakeMiniAppService();
    await tester.pumpWidget(_buildWorkshopApp(service));
    await tester.pumpAndSettle();

    expect(find.text('生成小工具'), findsOneWidget);
    expect(find.text('改造小工具'), findsOneWidget);
    expect(find.text('运行小工具'), findsOneWidget);
    expect(find.text('保存/分享小工具'), findsOneWidget);
    expect(find.text('最近：函数导数闪卡'), findsNWidgets(3));

    await tester.tap(find.text('运行最近'));
    await tester.pumpAndSettle();

    expect(find.text('running workshop_app_1'), findsOneWidget);
  });

  testWidgets(
    'software workshop revises an existing mini app from the action strip',
    (tester) async {
      await _setDesktopSurface(tester);
      final service = _FakeMiniAppService();
      await tester.pumpWidget(_buildWorkshopApp(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('改造最近'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始改造'));
      await tester.pumpAndSettle();

      expect(service.revisedAppId, 'workshop_app_1');
      expect(service.reviseInstruction, contains('更适合我现在复习'));
      expect(find.text('running workshop_app_1'), findsOneWidget);
    },
  );
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}

Widget _buildWorkshopApp(_FakeMiniAppService service) {
  final router = GoRouter(
    initialLocation: '/workshop',
    routes: [
      GoRoute(
        path: '/workshop',
        builder: (context, state) => const WorkshopPage(),
      ),
      GoRoute(
        path: '/workshop/builder',
        builder: (context, state) => const Text('builder'),
      ),
      GoRoute(
        path: '/workshop/apps/:appId',
        builder: (context, state) =>
            Text('running ${state.pathParameters['appId']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      miniAppServiceProvider.overrideWithValue(service),
      miniAppsProvider.overrideWith((ref) async => [_summary]),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

const _validation = MiniAppValidation(ok: true, errors: [], warnings: []);

const _summary = MiniAppSummary(
  id: 'workshop_app_1',
  title: '函数导数闪卡',
  appType: 'memory',
  subjectId: 1,
  status: 'draft',
  description: '用函数与导数资料生成的背记小工具。',
  updatedAt: '2026-06-05T10:00:00',
  validation: _validation,
);

const _record = MiniAppRecord(
  id: 'workshop_app_1',
  title: '函数导数闪卡',
  appType: 'memory',
  subjectId: 1,
  status: 'draft',
  documents: {},
  spec: {
    'content': {
      'items': [
        {'id': 'card_1', 'front': '导数定义', 'back': '函数变化率的极限'},
      ],
    },
  },
  graph: {},
  validation: _validation,
  updatedAt: '2026-06-05T10:00:00',
);

class _FakeMiniAppService implements MiniAppService {
  String? revisedAppId;
  String? reviseInstruction;

  @override
  Future<List<MiniAppSummary>> listApps() async => [_summary];

  @override
  Future<MiniAppRecord> getApp(String id) async => _record;

  @override
  Future<void> deleteApp(String id) async {}

  @override
  Future<MiniAppRecord> updateApp({
    required String id,
    String? title,
    Map<String, String>? documents,
    Map<String, dynamic>? spec,
    String? status,
  }) async => _record;

  @override
  Future<MiniAppRecord> reviseApp({
    required String id,
    required String instruction,
  }) async {
    revisedAppId = id;
    reviseInstruction = instruction;
    return _record;
  }

  @override
  Future<Map<String, dynamic>> getBlockRegistry() async => {};

  @override
  Future<MiniAppValidation> validateGraph({
    required Map<String, dynamic> graph,
    Map<String, dynamic>? spec,
  }) async => _validation;

  @override
  Future<Map<String, dynamic>> previewGraph(String id) async => {};

  @override
  Future<Map<String, dynamic>> startRun(String appId) async => {};

  @override
  Future<Map<String, dynamic>> appendRunEvent({
    required String runId,
    required String nodeId,
    required String eventType,
    Map<String, dynamic> payload = const {},
  }) async => {};

  @override
  Future<MiniAppInterviewTurn> startInterview({
    required String initialRequest,
    int? subjectId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GenerateCardsResult> generateCardsForApp({
    required String appId,
    List<int> documentIds = const [],
    bool useLlm = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MiniAppInterviewTurn> answerInterview({
    required String sessionId,
    required String answer,
  }) {
    throw UnimplementedError();
  }
}
