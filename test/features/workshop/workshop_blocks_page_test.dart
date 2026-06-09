import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_assistant_app/features/workshop/mini_app_models.dart';
import 'package:study_assistant_app/features/workshop/mini_app_providers.dart';
import 'package:study_assistant_app/features/workshop/mini_app_service.dart';
import 'package:study_assistant_app/features/workshop/workshop_blocks_page.dart';

void main() {
  testWidgets(
    'workshop blocks page loads registry and validates current workflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeMiniAppService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [miniAppServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: WorkshopBlocksPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('积木分类'), findsOneWidget);
      expect(find.text('事件'), findsWidgets);
      expect(find.text('当小工具开始运行'), findsWidgets);
      expect(find.text('资料角色'), findsOneWidget);
      expect(find.text('可引用资料'), findsOneWidget);

      await tester.tap(find.text('校验当前脚本'));
      await tester.pumpAndSettle();

      expect(service.validatedWorkflow, isNotNull);
      expect(find.text('通过'), findsOneWidget);
    },
  );

  testWidgets(
    'workshop blocks page can add a block, edit json, and validate it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _FakeMiniAppService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [miniAppServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: WorkshopBlocksPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, '资料'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '加入脚本'));
      await tester.pumpAndSettle();

      expect(find.text('编辑第 2 个积木'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '''
{
  "block": "resource.query",
  "params": {
    "query": {
      "subject_id": 1,
      "resource_types": ["mistake"],
      "limit": 5
    }
  },
  "output": "custom_materials"
}
''');
      await tester.tap(find.text('应用 JSON'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('校验当前脚本'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('校验当前脚本'));
      await tester.pumpAndSettle();

      final scripts = service.validatedWorkflow?['scripts'] as List?;
      final body = (scripts?.first as Map?)?['body'] as List?;
      expect(body, hasLength(2));
      expect((body?.last as Map?)?['output'], 'custom_materials');
      expect(find.text('通过'), findsOneWidget);
    },
  );
}

const _validation = MiniAppValidation(ok: true, errors: [], warnings: []);

class _FakeMiniAppService implements MiniAppService {
  Map<String, dynamic>? validatedWorkflow;

  @override
  Future<WorkshopWorkflowRegistry> getWorkflowRegistry() async =>
      WorkshopWorkflowRegistry.fromJson(_workflowRegistryJson);

  @override
  Future<List<WorkshopResourceActorType>> getResourceActorTypes() async => [
    WorkshopResourceActorType.fromJson({
      'id': 'lecture',
      'name': '讲义',
      'source_feature': 'course_space.mindmap_lecture',
      'read': true,
      'write': true,
    }),
  ];

  @override
  Future<WorkshopWorkflowValidationResult> validateWorkflow({
    required Map<String, dynamic> workflow,
  }) async {
    validatedWorkflow = workflow;
    return WorkshopWorkflowValidationResult(
      validation: _validation,
      normalized: workflow,
    );
  }

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
  Future<List<MiniAppSummary>> listApps() async => [];

  @override
  Future<MiniAppRecord> getApp(String id) {
    throw UnimplementedError();
  }

  @override
  Future<MiniAppVersionListResult> listAppVersions(String appId) async =>
      const MiniAppVersionListResult(
        appId: 'workshop_app_1',
        currentVersionId: 'workshop_app_1_v1',
        versions: [],
        total: 0,
      );

  @override
  Future<MiniAppVersion> getAppVersion({
    required String appId,
    required String versionId,
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MiniAppRecord> reviseApp({
    required String id,
    required String instruction,
  }) {
    throw UnimplementedError();
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

const _workflowRegistryJson = {
  'schema_version': '0.1.0',
  'runtime_schema_version': 'workshop.workflow.v1',
  'categories': [
    {'id': 'event', 'name': '事件', 'color': '#FFBF00'},
    {'id': 'resource', 'name': '资料', 'color': '#4C97FF'},
  ],
  'blocks': [
    {
      'id': 'event.on_start',
      'category': 'event',
      'shape': 'hat',
      'label': '当小工具开始运行',
    },
    {
      'id': 'resource.query',
      'category': 'resource',
      'shape': 'reporter',
      'label': '从资料库查询 {query}',
      'returns': 'ResourceSet',
      'outputs': [
        {'name': 'materials', 'type': 'ResourceSet'},
      ],
      'params': [
        {'name': 'query', 'slot': 'resource_query', 'required': true},
      ],
    },
  ],
  'resource_actor_types': [
    {
      'id': 'mindmap.node',
      'name': '导图节点',
      'source_feature': 'course_space.mindmap_lecture',
      'read': true,
      'write': true,
    },
    {
      'id': 'mistake',
      'name': '错题',
      'source_feature': 'review.mistakes',
      'read': true,
      'write': true,
    },
  ],
  'example_workflow': {
    'schema_version': 'workshop.workflow.v1',
    'actors': [
      {
        'id': 'weak_mistakes',
        'name': '薄弱错题',
        'type': 'mistake',
        'query': {'subject_id': 1},
      },
    ],
    'scripts': [
      {
        'id': 'script_on_start',
        'hat': {'block': 'event.on_start'},
        'body': [
          {
            'block': 'resource.query',
            'params': {
              'query': {
                'subject_id': 1,
                'resource_types': ['mistake'],
              },
            },
            'output': 'materials',
          },
        ],
      },
    ],
  },
};
