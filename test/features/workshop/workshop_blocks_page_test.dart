import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_assistant_app/features/workshop/mini_app_models.dart';
import 'package:study_assistant_app/features/workshop/mini_app_providers.dart';
import 'package:study_assistant_app/features/workshop/mini_app_service.dart';
import 'package:study_assistant_app/features/workshop/workshop_blocks_page.dart';

void main() {
  testWidgets('workshop blocks page loads registry and validates workflow', (
    tester,
  ) async {
    await _setDesktopSurface(tester);
    final service = _FakeMiniAppService();
    await tester.pumpWidget(_buildPage(service));
    await tester.pumpAndSettle();

    expect(find.byType(FilterChip), findsNWidgets(2));
    expect(find.byIcon(Icons.category_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fact_check_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fact_check_rounded));
    await tester.pumpAndSettle();

    expect(service.validatedWorkflow, isNotNull);
  });

  testWidgets('workshop blocks page can add a block, edit json, and validate', (
    tester,
  ) async {
    await _setDesktopSurface(tester);
    final service = _FakeMiniAppService();
    await tester.pumpWidget(_buildPage(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilterChip).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '''
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
    await tester.tap(find.byIcon(Icons.done_rounded).first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byIcon(Icons.fact_check_rounded),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byIcon(Icons.fact_check_rounded).last);
    await tester.pumpAndSettle();

    final scripts = service.validatedWorkflow?['scripts'] as List?;
    final body = (scripts?.first as Map?)?['body'] as List?;
    expect(body, hasLength(2));
    expect((body?.last as Map?)?['output'], 'custom_materials');
  });

  testWidgets('workshop blocks page previews and applies workflow patch', (
    tester,
  ) async {
    await _setDesktopSurface(tester);
    final service = _FakeMiniAppService();
    await tester.pumpWidget(_buildPage(service));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byIcon(Icons.preview_rounded),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(find.byType(TextField).last, 'limit to 5 materials');
    await tester.tap(find.byIcon(Icons.preview_rounded));
    await tester.pumpAndSettle();

    expect(service.patchInstruction, 'limit to 5 materials');
    expect(_textContaining('应用 patch'), findsOneWidget);
    expect(find.text('params.query.limit'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.done_rounded).last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.fact_check_rounded),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byIcon(Icons.fact_check_rounded).last);
    await tester.pumpAndSettle();

    final scripts = service.validatedWorkflow?['scripts'] as List?;
    final body = (scripts?.first as Map?)?['body'] as List?;
    final firstBlock = (body?.first as Map?)?.cast<String, dynamic>();
    final params = (firstBlock?['params'] as Map?)?.cast<String, dynamic>();
    final query = (params?['query'] as Map?)?.cast<String, dynamic>();
    expect(query?['limit'], 5);
  });
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}

Finder _textContaining(String value) {
  return find.byWidgetPredicate((widget) {
    return widget is Text && (widget.data?.contains(value) ?? false);
  });
}

Widget _buildPage(_FakeMiniAppService service) {
  return ProviderScope(
    overrides: [miniAppServiceProvider.overrideWithValue(service)],
    child: const MaterialApp(home: WorkshopBlocksPage()),
  );
}

const _validation = MiniAppValidation(ok: true, errors: [], warnings: []);

class _FakeMiniAppService implements MiniAppService {
  Map<String, dynamic>? validatedWorkflow;
  String? patchInstruction;

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
  }) async {
    patchInstruction = instruction;
    final scripts = workflow['scripts'] as List;
    final firstScript = (scripts.first as Map).cast<String, dynamic>();
    final body = firstScript['body'] as List;
    final firstBlock = (body.first as Map).cast<String, dynamic>();
    final params = (firstBlock['params'] as Map).cast<String, dynamic>();
    final query = (params['query'] as Map).cast<String, dynamic>();
    query['limit'] = 5;
    params['query'] = query;
    firstBlock['params'] = params;
    body[0] = firstBlock;
    firstScript['body'] = body;
    scripts[0] = firstScript;
    workflow['scripts'] = scripts;

    return WorkshopWorkflowPatchResult(
      patch: const [
        {
          'op': 'set_param',
          'target': {
            'script_index': 0,
            'block_index': 0,
            'block_id': 'resource.query',
            'path': 'scripts[0].body[0]',
          },
          'field': 'params.query.limit',
          'before': null,
          'after': 5,
          'reason': 'limit materials',
        },
      ],
      workflow: workflow,
      validation: _validation,
      changed: const ['params.query.limit'],
    );
  }

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
