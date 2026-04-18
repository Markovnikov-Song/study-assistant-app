import 'dart:async';
import 'dart:convert';
import 'dart:io';

Stream<String> ssePost(String url, Map<String, dynamic> body, String? token) {
  final ctrl = StreamController<String>();

  Future<void> fetch() async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode(body));

      final response = await request.close();
      String leftover = '';

      await for (final chunk in response.transform(utf8.decoder)) {
        final text = leftover + chunk;
        // 只有以 \n 结尾的 chunk 才说明最后一行是完整的
        final endsWithNewline = text.endsWith('\n');
        final lines = text.split('\n');
        // 如果不以换行结尾，最后一行可能不完整，保留为 leftover
        final processCount = endsWithNewline ? lines.length : lines.length - 1;
        leftover = endsWithNewline ? '' : lines.last;

        for (var i = 0; i < processCount; i++) {
          final line = lines[i];
          if (line.startsWith('data: ')) {
            ctrl.add(line.substring(6));
          }
          // 忽略空行和其他 SSE 字段（event:, id:, retry: 等）
        }
      }
      // 处理最后可能残留的内容
      if (leftover.startsWith('data: ')) {
        ctrl.add(leftover.substring(6));
      }
      client.close();
      ctrl.close();
    } catch (e, st) {
      ctrl.addError(e, st);
      ctrl.close();
    }
  }

  fetch();
  return ctrl.stream;
}
