// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Stream<String> ssePost(String url, Map<String, dynamic> body, String? token) {
  final ctrl = StreamController<String>();

  final xhr = html.HttpRequest();
  xhr.open('POST', url, async: true);
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.setRequestHeader('Accept', 'text/event-stream');
  if (token != null) xhr.setRequestHeader('Authorization', 'Bearer $token');

  int processed = 0;

  xhr.onProgress.listen((_) {
    final text = xhr.responseText ?? '';
    if (text.length <= processed) return;
    final newChunk = text.substring(processed);
    processed = text.length;

    for (final line in newChunk.split('\n')) {
      if (line.startsWith('data: ')) {
        ctrl.add(line.substring(6).replaceAll(r'\n', '\n').replaceAll(r'\r', '\r'));
      }
    }
  });

  xhr.onLoad.listen((_) {
    // 检查 HTTP 状态码，非 2xx 直接抛出错误
    if (xhr.status < 200 || xhr.status >= 300) {
      final errorBody = xhr.responseText ?? '';
      ctrl.addError(Exception('HTTP ${xhr.status}: ${errorBody.isNotEmpty ? errorBody : 'Request failed'}'));
      ctrl.close();
      return;
    }
    
    // 处理最后剩余内容
    final text = xhr.responseText ?? '';
    if (text.length > processed) {
      for (final line in text.substring(processed).split('\n')) {
        if (line.startsWith('data: ')) ctrl.add(line.substring(6).replaceAll(r'\n', '\n').replaceAll(r'\r', '\r'));
      }
    }
    ctrl.close();
  });

  xhr.onError.listen((e) {
    ctrl.addError(Exception('SSE request failed'));
    ctrl.close();
  });

  xhr.send(jsonEncode(body));

  return ctrl.stream;
}
