import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_assistant_app/features/workshop/mini_app_models.dart';
import 'package:study_assistant_app/features/workshop/mini_app_providers.dart';
import 'package:study_assistant_app/features/workshop/mini_app_run_page.dart';
import 'package:study_assistant_app/features/workshop/mini_app_service.dart';

void main() {
  testWidgets('mini app run page shows version history and run-bound version', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _FakeMiniAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [miniAppServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: MiniAppRunPage(appId: 'workshop_app_1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.startedAppId, 'workshop_app_1');
    await tester.scrollUntilVisible(
      find.byIcon(Icons.history_rounded),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('版本历史'), findsOneWidget);
    expect(find.textContaining('当前版本：app_v2'), findsOneWidget);
    expect(find.textContaining('运行绑定版本：app_v2'), findsOneWidget);
    expect(find.textContaining('父版本：app_v1'), findsOneWidget);
    expect(find.textContaining('改动字段：spec / documents'), findsOneWidget);
    expect(find.textContaining('把题量调成 10 题'), findsOneWidget);
  });
}

const _validation = MiniAppValidation(ok: true, errors: [], warnings: []);

const _record = MiniAppRecord(
  id: 'workshop_app_1',
  title: '函数导数闪卡',
  appType: 'memory',
  subjectId: 1,
  status: 'draft',
  currentVersionId: 'app_v2',
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

const _versions = MiniAppVersionListResult(
  appId: 'workshop_app_1',
  currentVersionId: 'app_v2',
  total: 2,
  versions: [
    MiniAppVersion(
      id: 'app_v2',
      appId: 'workshop_app_1',
      userId: 'user_1',
      sequence: 2,
      parentVersionId: 'app_v1',
      source: 'revise',
      instruction: '把题量调成 10 题',
      changed: ['spec', 'documents'],
      summary: 'AI 改造了运行配置和文档',
      snapshot: {},
      createdAt: '2026-06-05T11:00:00',
    ),
    MiniAppVersion(
      id: 'app_v1',
      appId: 'workshop_app_1',
      userId: 'user_1',
      sequence: 1,
      parentVersionId: null,
      source: 'create',
      instruction: null,
      changed: ['spec'],
      summary: '创建初始版本',
      snapshot: {},
      createdAt: '2026-06-05T10:00:00',
    ),
  ],
);

class _FakeMiniAppService implements MiniAppService {
  String? startedAppId;

  @override
  Future<List<MiniAppSummary>> listApps() async => [];

  @override
  Future<MiniAppRecord> getApp(String id) async => _record;

  @override
  Future<MiniAppVersionListResult> listAppVersions(String appId) async =>
      _versions;

  @override
  Future<MiniAppVersion> getAppVersion({
    required String appId,
    required String versionId,
  }) async {
    return _versions.versions.firstWhere((version) => version.id == versionId);
  }

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
  }) async => _record;

  @override
  Future<Map<String, dynamic>> getBlockRegistry() async => {};

  @override
  Future<WorkshopWorkflowRegistry> getWorkflowRegistry() {
    throw UnimplementedError();
  }

  @override
  Future<List<WorkshopResourceActorType>> getResourceActorTypes() async => [];

  @override
  Future<WorkshopWorkflowValidationResult> validateWorkflow({
    required Map<String, dynamic> workflow,
  }) async => WorkshopWorkflowValidationResult(
    validation: _validation,
    normalized: workflow,
  );

  @override
  Future<WorkshopWorkflowPatchResult> patchWorkflow({
    required Map<String, dynamic> workflow,
    required String instruction,
  }) async => WorkshopWorkflowPatchResult(
    patch: const [],
    workflow: workflow,
    validation: _validation,
    changed: const [],
  );

  @override
  Future<MiniAppValidation> validateGraph({
    required Map<String, dynamic> graph,
    Map<String, dynamic>? spec,
  }) async => _validation;

  @override
  Future<Map<String, dynamic>> previewGraph(String id) async => {};

  @override
  Future<Map<String, dynamic>> startRun(String appId) async {
    startedAppId = appId;
    return {'run_id': 'run_1', 'app_version_id': 'app_v2'};
  }

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
