import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/services/book_export_service.dart';

/// A simple [HttpClientAdapter] that returns a pre-configured response.
class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;

  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

/// Builds a [Dio] instance whose adapter is replaced with [adapter].
Dio _dioWith(_MockAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('BookExportService', () {
    // ------------------------------------------------------------------ //
    // 1. Request construction                                              //
    // ------------------------------------------------------------------ //
    test('constructs correct URL, body params, and responseType', () async {
      RequestOptions? captured;

      final adapter = _MockAdapter((opts) async {
        captured = opts;
        return ResponseBody.fromBytes(
          Uint8List.fromList([1, 2, 3]),
          200,
        );
      });

      final service = BookExportService(dio: _dioWith(adapter));

      await service.exportBook(
        sessionId: 42,
        nodeIds: ['n1', 'n2'],
        format: 'pdf',
        includeToc: false,
      );

      expect(captured, isNotNull);
      expect(captured!.path, equals('/api/library/sessions/42/export-book'));
      expect(captured!.method, equals('POST'));

      final body = captured!.data as Map<String, dynamic>;
      expect(body['node_ids'], equals(['n1', 'n2']));
      expect(body['format'], equals('pdf'));
      expect(body['include_toc'], isFalse);

      expect(captured!.responseType, equals(ResponseType.bytes));
    });

    test('includeToc defaults to true', () async {
      RequestOptions? captured;

      final adapter = _MockAdapter((opts) async {
        captured = opts;
        return ResponseBody.fromBytes(Uint8List.fromList([0]), 200);
      });

      final service = BookExportService(dio: _dioWith(adapter));
      await service.exportBook(
        sessionId: 1,
        nodeIds: ['x'],
        format: 'docx',
      );

      final body = captured!.data as Map<String, dynamic>;
      expect(body['include_toc'], isTrue);
    });

    // ------------------------------------------------------------------ //
    // 2. Successful response                                               //
    // ------------------------------------------------------------------ //
    test('returns Uint8List from successful response', () async {
      final bytes = Uint8List.fromList([10, 20, 30, 40]);

      final adapter = _MockAdapter(
        (_) async => ResponseBody.fromBytes(bytes, 200),
      );

      final service = BookExportService(dio: _dioWith(adapter));
      final result = await service.exportBook(
        sessionId: 7,
        nodeIds: ['a'],
        format: 'pdf',
      );

      expect(result, equals(bytes));
    });

    // ------------------------------------------------------------------ //
    // 3. Timeout → BookExportException with timeout message               //
    // ------------------------------------------------------------------ //
    test('receiveTimeout surfaces as BookExportException with timeout message',
        () async {
      final adapter = _MockAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.receiveTimeout,
        );
      });

      final service = BookExportService(dio: _dioWith(adapter));

      expect(
        () => service.exportBook(
          sessionId: 1,
          nodeIds: ['n'],
          format: 'pdf',
        ),
        throwsA(
          isA<BookExportException>().having(
            (e) => e.message,
            'message',
            equals('导出超时，请减少选择的节点数量后重试'),
          ),
        ),
      );
    });

    // ------------------------------------------------------------------ //
    // 4. HTTP error → backend detail message passed through               //
    // ------------------------------------------------------------------ //
    test('HTTP 422 passes through backend detail message', () async {
      final adapter = _MockAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 422,
            data: {'detail': '所选节点均无讲义内容'},
          ),
        );
      });

      final service = BookExportService(dio: _dioWith(adapter));

      expect(
        () => service.exportBook(
          sessionId: 1,
          nodeIds: ['n'],
          format: 'pdf',
        ),
        throwsA(
          isA<BookExportException>()
              .having((e) => e.message, 'message', equals('所选节点均无讲义内容'))
              .having((e) => e.statusCode, 'statusCode', equals(422)),
        ),
      );
    });

    test('HTTP error without detail falls back to 导出失败', () async {
      final adapter = _MockAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 500,
            data: 'Internal Server Error',
          ),
        );
      });

      final service = BookExportService(dio: _dioWith(adapter));

      expect(
        () => service.exportBook(
          sessionId: 1,
          nodeIds: ['n'],
          format: 'pdf',
        ),
        throwsA(
          isA<BookExportException>()
              .having((e) => e.message, 'message', equals('导出失败'))
              .having((e) => e.statusCode, 'statusCode', equals(500)),
        ),
      );
    });

    // ------------------------------------------------------------------ //
    // 5. Other DioException → generic BookExportException                 //
    // ------------------------------------------------------------------ //
    test('other DioException wraps message in BookExportException', () async {
      final adapter = _MockAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
          message: '网络连接失败',
        );
      });

      final service = BookExportService(dio: _dioWith(adapter));

      expect(
        () => service.exportBook(
          sessionId: 1,
          nodeIds: ['n'],
          format: 'pdf',
        ),
        throwsA(
          isA<BookExportException>().having(
            (e) => e.message,
            'message',
            equals('网络连接失败'),
          ),
        ),
      );
    });
  });
}
