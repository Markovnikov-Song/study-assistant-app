// Preservation Property Tests — Missing Implementations Fix
//
// These tests verify that the 4 bug fixes do NOT break any existing behavior.
// They encode the "Preservation" property from design.md:
//   For all inputs NOT satisfying the Bug Conditions, behavior is unchanged.
//
// Run BEFORE and AFTER fixes — should PASS in both cases.
//
// Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/tools/ocr/ocr_api_client.dart';
import 'package:study_assistant_app/models/chat_message.dart';

// ─── Minimal Dio interceptor to capture outgoing requests ────────────────────

class _CapturingInterceptor extends Interceptor {
  String? capturedPath;
  Map<String, dynamic>? capturedData;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    capturedPath = options.path;
    capturedData = options.data as Map<String, dynamic>?;
    // Return a fake 200 response so the client doesn't throw.
    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: 200,
        data: {'text': '识别结果'},
      ),
    );
  }
}

void main() {
  // ─── Preservation 1: OCR /api/ocr/image endpoint still works ────────────────
  //
  // Requirement 3.1: POST /api/ocr/image continues to work normally.
  // The fix changed the Flutter client to call /api/ocr/image — this test
  // confirms the client still calls /api/ocr/image (not some other path).
  group('Preservation 1 — OCR: OcrApiClient still calls /api/ocr/image', () {
    test(
      'recognize() sends POST to /api/ocr/image (preserved after fix)',
      () async {
        final interceptor = _CapturingInterceptor();
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.interceptors.add(interceptor);

        final client = OcrApiClient(dio);
        final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

        await client.recognize(fakeBytes, 'photo.jpg');

        // Preservation: the fixed client must still call /api/ocr/image.
        expect(
          interceptor.capturedPath,
          equals('/api/ocr/image'),
          reason:
              'Preservation 3.1: OcrApiClient must continue to call /api/ocr/image',
        );
      },
    );

    test(
      'recognize() sends JSON body with "image" key (preserved after fix)',
      () async {
        final interceptor = _CapturingInterceptor();
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.interceptors.add(interceptor);

        final client = OcrApiClient(dio);
        final fakeBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

        await client.recognize(fakeBytes, 'image.png');

        expect(
          interceptor.capturedData,
          isA<Map<String, dynamic>>(),
          reason: 'Preservation 3.1: request body must remain a JSON map',
        );
        expect(
          interceptor.capturedData!.containsKey('image'),
          isTrue,
          reason: 'Preservation 3.1: request body must still contain "image" key',
        );
      },
    );
  });

  // ─── Preservation 2: Other SceneType navigation logic unchanged ──────────────
  //
  // Requirement 3.2: subject, tool, spec, calendar navigation logic unchanged.
  // We verify the source code still contains the correct navigation for each
  // non-planning SceneType.
  group('Preservation 2 — SceneType: non-planning navigation logic unchanged', () {
    late String chatPageContent;

    setUpAll(() {
      final file = File('lib/features/chat/chat_page.dart');
      expect(file.existsSync(), isTrue, reason: 'chat_page.dart must exist');
      chatPageContent = file.readAsStringSync();
    });

    test(
      'SceneType.subject case still navigates to subject chat route',
      () {
        // The subject case should push a route containing 'subject'.
        final caseSubjectIdx = chatPageContent.indexOf('case SceneType.subject:');
        expect(
          caseSubjectIdx,
          isNot(-1),
          reason: 'chat_page.dart must have case SceneType.subject',
        );

        // Extract the subject case block (300 chars is enough).
        final afterSubject = chatPageContent.substring(
          caseSubjectIdx,
          caseSubjectIdx + 300,
        );

        expect(
          afterSubject.contains('context.push'),
          isTrue,
          reason:
              'Preservation 3.2: SceneType.subject case must still call context.push',
        );
        expect(
          afterSubject.contains('subject'),
          isTrue,
          reason:
              'Preservation 3.2: SceneType.subject navigation must still reference "subject"',
        );
      },
    );

    test(
      'SceneType.tool case still navigates using toolRoute payload',
      () {
        final caseToolIdx = chatPageContent.indexOf('case SceneType.tool:');
        expect(
          caseToolIdx,
          isNot(-1),
          reason: 'chat_page.dart must have case SceneType.tool',
        );

        final afterTool = chatPageContent.substring(
          caseToolIdx,
          caseToolIdx + 200,
        );

        expect(
          afterTool.contains('context.push'),
          isTrue,
          reason:
              'Preservation 3.2: SceneType.tool case must still call context.push',
        );
      },
    );

    test(
      'SceneType.spec case still navigates to /spec',
      () {
        final caseSpecIdx = chatPageContent.indexOf('case SceneType.spec:');
        expect(
          caseSpecIdx,
          isNot(-1),
          reason: 'chat_page.dart must have case SceneType.spec',
        );

        final afterSpec = chatPageContent.substring(
          caseSpecIdx,
          caseSpecIdx + 100,
        );

        expect(
          afterSpec.contains("context.push('/spec')"),
          isTrue,
          reason:
              "Preservation 3.2: SceneType.spec case must still call context.push('/spec')",
        );
      },
    );

    test(
      'SceneType.calendar case still shows modal bottom sheet',
      () {
        final caseCalendarIdx = chatPageContent.indexOf('case SceneType.calendar:');
        expect(
          caseCalendarIdx,
          isNot(-1),
          reason: 'chat_page.dart must have case SceneType.calendar',
        );

        final afterCalendar = chatPageContent.substring(
          caseCalendarIdx,
          caseCalendarIdx + 300,
        );

        expect(
          afterCalendar.contains('showModalBottomSheet'),
          isTrue,
          reason:
              'Preservation 3.2: SceneType.calendar case must still show modal bottom sheet',
        );
      },
    );

    test(
      'SceneType enum still contains all original values',
      () {
        // All original SceneType values must still exist.
        expect(SceneType.values.contains(SceneType.subject), isTrue);
        expect(SceneType.values.contains(SceneType.tool), isTrue);
        expect(SceneType.values.contains(SceneType.spec), isTrue);
        expect(SceneType.values.contains(SceneType.calendar), isTrue);
        expect(SceneType.values.contains(SceneType.planning), isTrue);
      },
    );
  });

  // ─── Preservation 3: Real SkillMarketplaceService callers unchanged ──────────
  //
  // Requirement 3.3: marketplace_page.dart and skill_detail_page.dart continue
  // to import from core/skill/ (the real implementation).
  group('Preservation 3 — SkillMarketplaceService: callers use real implementation', () {
    test(
      'marketplace_page.dart imports from core/skill/skill_marketplace_service.dart',
      () {
        final file = File('lib/features/skill_marketplace/marketplace_page.dart');
        expect(file.existsSync(), isTrue, reason: 'marketplace_page.dart must exist');

        final content = file.readAsStringSync();

        expect(
          content.contains('core/skill/skill_marketplace_service.dart'),
          isTrue,
          reason:
              'Preservation 3.3: marketplace_page.dart must import from core/skill/',
        );

        // Must NOT import the deleted placeholder.
        expect(
          content.contains("'../../services/skill_marketplace_service.dart'"),
          isFalse,
          reason:
              'Preservation 3.3: marketplace_page.dart must not import the placeholder',
        );
      },
    );

    test(
      'skill_detail_page.dart imports from core/skill/skill_marketplace_service.dart',
      () {
        final file = File('lib/features/skill_marketplace/skill_detail_page.dart');
        expect(file.existsSync(), isTrue, reason: 'skill_detail_page.dart must exist');

        final content = file.readAsStringSync();

        expect(
          content.contains('core/skill/skill_marketplace_service.dart'),
          isTrue,
          reason:
              'Preservation 3.3: skill_detail_page.dart must import from core/skill/',
        );

        // Must NOT import the deleted placeholder.
        expect(
          content.contains("'../../services/skill_marketplace_service.dart'"),
          isFalse,
          reason:
              'Preservation 3.3: skill_detail_page.dart must not import the placeholder',
        );
      },
    );

    test(
      'real SkillMarketplaceService at core/skill/ still exists',
      () {
        final realFile = File('lib/core/skill/skill_marketplace_service.dart');
        expect(
          realFile.existsSync(),
          isTrue,
          reason:
              'Preservation 3.3: real SkillMarketplaceService must still exist at core/skill/',
        );
      },
    );

    test(
      'real SkillMarketplaceService calls real API endpoints (not placeholder data)',
      () {
        final file = File('lib/core/skill/skill_marketplace_service.dart');
        final content = file.readAsStringSync();

        // The real implementation must call /api/marketplace/ endpoints.
        expect(
          content.contains('/api/marketplace/'),
          isTrue,
          reason:
              'Preservation 3.3: real SkillMarketplaceService must call /api/marketplace/ endpoints',
        );

        // Must use Dio for real HTTP calls.
        expect(
          content.contains('_dio.'),
          isTrue,
          reason:
              'Preservation 3.3: real SkillMarketplaceService must use Dio for HTTP calls',
        );
      },
    );
  });

  // ─── Preservation 4: Agent endpoint source code unchanged ───────────────────
  //
  // Requirement 3.4: /api/agent/resolve-intent, /api/agent/execute-node, etc.
  // continue to work normally. We verify the backend agent.py still contains
  // these endpoints.
  group('Preservation 4 — Agent endpoints: existing routes still present', () {
    late String agentPyContent;

    setUpAll(() {
      final file = File('backend/routers/agent.py');
      expect(file.existsSync(), isTrue, reason: 'backend/routers/agent.py must exist');
      agentPyContent = file.readAsStringSync();
    });

    test(
      'agent.py still contains /resolve-intent endpoint',
      () {
        expect(
          agentPyContent.contains('resolve-intent') ||
              agentPyContent.contains('resolve_intent'),
          isTrue,
          reason:
              'Preservation 3.4: agent.py must still have resolve-intent endpoint',
        );
      },
    );

    test(
      'agent.py still contains /execute-node endpoint',
      () {
        expect(
          agentPyContent.contains('execute-node') ||
              agentPyContent.contains('execute_node'),
          isTrue,
          reason:
              'Preservation 3.4: agent.py must still have execute-node endpoint',
        );
      },
    );

    test(
      'agent.py still contains /skills endpoint',
      () {
        expect(
          agentPyContent.contains('/skills') ||
              agentPyContent.contains('"skills"') ||
              agentPyContent.contains("'skills'"),
          isTrue,
          reason:
              'Preservation 3.4: agent.py must still have /skills endpoint',
        );
      },
    );

    test(
      'agent.py still contains /parser/config endpoint',
      () {
        expect(
          agentPyContent.contains('parser/config') ||
              agentPyContent.contains('parser_config'),
          isTrue,
          reason:
              'Preservation 3.4: agent.py must still have /parser/config endpoint',
        );
      },
    );

    test(
      'newly added /parse endpoint does not replace existing endpoints',
      () {
        // The new /parse endpoint was added — verify it coexists with others.
        expect(
          agentPyContent.contains('/parse') ||
              agentPyContent.contains('"parse"') ||
              agentPyContent.contains("'parse'"),
          isTrue,
          reason:
              'Preservation 3.4: agent.py must contain the new /parse endpoint',
        );

        // And the old endpoints must still be there.
        expect(
          agentPyContent.contains('resolve-intent') ||
              agentPyContent.contains('resolve_intent'),
          isTrue,
          reason:
              'Preservation 3.4: adding /parse must not remove resolve-intent',
        );
      },
    );
  });

  // ─── Preservation 5: skill_parser_impl.dart calls /api/agent/parse ──────────
  //
  // Requirement 3.4: The Flutter skill parser now calls /api/agent/parse.
  // This is the fixed path — verify it's preserved correctly.
  group('Preservation 5 — SkillParser: calls /api/agent/parse (not old path)', () {
    test(
      'skill_parser_impl.dart calls /api/agent/parse',
      () {
        final file = File('lib/core/skill/skill_parser_impl.dart');
        expect(file.existsSync(), isTrue, reason: 'skill_parser_impl.dart must exist');

        final content = file.readAsStringSync();

        expect(
          content.contains('/api/agent/parse'),
          isTrue,
          reason:
              'Preservation: skill_parser_impl.dart must call /api/agent/parse',
        );

        // Must NOT call the old broken path.
        final dioPostIdx = content.indexOf('_dio.post(');
        if (dioPostIdx != -1) {
          final dioPostSection = content.substring(dioPostIdx, dioPostIdx + 100);
          expect(
            dioPostSection.contains('/api/skills/parse'),
            isFalse,
            reason:
                'Preservation: skill_parser_impl.dart must not call /api/skills/parse',
          );
        }
      },
    );
  });
}
