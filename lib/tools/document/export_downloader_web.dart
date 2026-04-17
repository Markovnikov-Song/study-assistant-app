import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web 平台：用 XHR 发 POST 请求，获取二进制响应。
/// 绕过 Dio 在 Web 上 ResponseType.bytes 的问题。
Future<List<int>> fetchExportBytes(
    String url, Map<String, dynamic> body, String? token) {
  final completer = Completer<List<int>>();
  final xhr = html.HttpRequest();
  xhr.open('POST', url, async: true);
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.setRequestHeader('Accept', '*/*');
  if (token != null) xhr.setRequestHeader('Authorization', 'Bearer $token');
  xhr.responseType = 'arraybuffer';

  xhr.onLoad.listen((_) {
    if (xhr.status == 200) {
      final buffer = xhr.response as ByteBuffer;
      completer.complete(buffer.asUint8List().toList());
    } else {
      completer.completeError(
          Exception('导出失败：HTTP ${xhr.status}'));
    }
  });
  xhr.onError.listen((_) {
    completer.completeError(Exception('网络请求失败'));
  });

  xhr.send(jsonEncode(body));
  return completer.future;
}
