// Bug Condition Exploration Tests — Missing Implementations Fix
//
// These tests encode the EXPECTED (fixed) behavior for the 4 bugs.
// On unfixed code they would FAIL — failure confirms the bug exists.
// After fixes are applied (tasks 3.1–3.4), these tests should PASS.
//
// Validates: Requirements 2.1, 2.2, 2.3, 2.4

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
  // ─── Bug 1: OCR path ────────────────────────────────────────────────────────
  group('Bug 1 — OCR path: OcrApiClient.recognize() sends to /api/ocr/image', () {
    test(
      'recognize() sends POST to /api/ocr/image (not /api/ocr/recognize)',
      () async {
        // Arrange: create a Dio instance with a capturing interceptor.
        final interceptor = _CapturingInterceptor();
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.interceptors.add(interceptor);

        final client = OcrApiClient(dio);
        final fakeBytes = Uint8List.fromList([0, 1, 2, 3]);

        // Act
        await client.recognize(fakeBytes, 'test.jpg');

        // Assert: the fixed code must call /api/ocr/image, NOT /api/ocr/recognize.
        expect(
          interceptor.capturedPath,
          equals('/api/ocr/image'),
          reason:
              'Bug 1 fix: OcrApiClient must call /api/ocr/image, not /api/ocr/recognize',
        );
      },
    );

    test(
      'recognize() sends JSON body with "image" key (not multipart FormData)',
      () async {
        final interceptor = _CapturingInterceptor();
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
        dio.interceptors.add(interceptor);

        final client = OcrApiClient(dio);
        final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

        await client.recognize(fakeBytes, 'photo.jpg');

        // The request body must be a JSON map with an "image" key.
        expect(
          interceptor.capturedData,
          isA<Map<String, dynamic>>(),
          reason: 'Request body must be a JSON map, not FormData',
        );
        expect(
          interceptor.capturedData!.containsKey('image'),
          isTrue,
          reason: 'Request body must contain "image" key with base64 string',
        );
      },
    );
  });

  // ─── Bug 2: Parse endpoint ──────────────────────────────────────────────────
  // This test verifies the backend endpoint exists by checking the route
  // is registered. We test this at the Dart level by verifying the client
  // calls /api/agent/parse (not /api/skills/parse).
  group('Bug 2 — Parse endpoint: skill_parser_impl calls /api/agent/parse', () {
    test(
      'AiSkillParser calls /api/agent/parse (not /api/skills/parse)',
      () async {
        // We verify the source code directly: the fixed file must reference
        // /api/agent/parse in the actual _dio.post() call.
        final file = File('lib/core/skill/skill_parser_impl.dart');
        expect(file.existsSync(), isTrue, reason: 'skill_parser_impl.dart must exist');

        final content = file.readAsStringSync();

        // The actual _dio.post() call must use /api/agent/parse.
        expect(
          content.contains('/api/agent/parse'),
          isTrue,
          reason: 'Bug 2 fix: skill_parser_impl.dart must call /api/agent/parse',
        );

        // The _dio.post() call must NOT use the old /api/skills/parse path.
        // Note: we check the actual code call, not comments.
        // Find the _dio.post() call and verify it uses the correct path.
        final dioPostIdx = content.indexOf("_dio.post(");
        expect(dioPostIdx, isNot(-1), reason: '_dio.post() call must exist');

        final dioPostSection = content.substring(dioPostIdx, dioPostIdx + 100);
        expect(
          dioPostSection.contains('/api/skills/parse'),
          isFalse,
          reason: 'Bug 2 fix: _dio.post() must not call /api/skills/parse',
        );
        expect(
          dioPostSection.contains('/api/agent/parse'),
          isTrue,
          reason: 'Bug 2 fix: _dio.post() must call /api/agent/parse',
        );
      },
    );
  });

  // ─── Bug 3: Planning navigation ─────────────────────────────────────────────
  group('Bug 3 — Planning navigation: context.push("/spec") is called', () {
    test(
      'chat_page.dart contains context.push for SceneType.planning (not just break)',
      () {
        // Verify the source code directly: the fixed file must have
        // context.push('/spec') under the planning case, not just break.
        final file = File('lib/features/chat/chat_page.dart');
        expect(file.existsSync(), isTrue, reason: 'chat_page.dart must exist');

        final content = file.readAsStringSync();

        // Find the switch case for SceneType.planning.
        final casePlanningIdx = content.indexOf('case SceneType.planning:');
        expect(
          casePlanningIdx,
          isNot(-1),
          reason: 'chat_page.dart must have a case for SceneType.planning',
        );

        // Extract the planning case block (200 chars is enough to see the next line).
        final afterPlanning = content.substring(casePlanningIdx, casePlanningIdx + 200);

        expect(
          afterPlanning.contains("context.push('/spec')"),
          isTrue,
          reason:
              "Bug 3 fix: SceneType.planning case must call context.push('/spec'), not just break",
        );
      },
    );

    test(
      'SceneType enum contains planning value',
      () {
        // Verify SceneType.planning exists in the enum.
        expect(
          SceneType.values.contains(SceneType.planning),
          isTrue,
          reason: 'SceneType.planning must be defined in the enum',
        );
      },
    );
  });

  // ─── Bug 4: Placeholder file ─────────────────────────────────────────────────
  group('Bug 4 — Placeholder file: lib/services/skill_marketplace_service.dart does NOT exist', () {
    test(
      'placeholder file lib/services/skill_marketplace_service.dart does not exist',
      () {
        final placeholderFile = File('lib/services/skill_marketplace_service.dart');

        expect(
          placeholderFile.existsSync(),
          isFalse,
          reason:
              'Bug 4 fix: placeholder file lib/services/skill_marketplace_service.dart '
              'must be deleted to eliminate ambiguous reference risk',
        );
      },
    );

    test(
      'real implementation lib/core/skill/skill_marketplace_service.dart still exists',
      () {
        final realFile = File('lib/core/skill/skill_marketplace_service.dart');

        expect(
          realFile.existsSync(),
          isTrue,
          reason:
              'The real SkillMarketplaceService at lib/core/skill/ must still exist',
        );
      },
    );
  });
}
