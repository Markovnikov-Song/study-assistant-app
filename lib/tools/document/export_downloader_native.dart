import 'dart:convert';
import 'dart:io';

/// Native 平台：用 dart:io HttpClient 发 POST 请求获取二进制响应。
Future<List<int>> fetchExportBytes(
    String url, Map<String, dynamic> body, String? token) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final req = await client.postUrl(uri);
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Accept', '*/*');
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    req.write(jsonEncode(body));
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('导出失败：HTTP ${res.statusCode}');
    }
    final chunks = <int>[];
    await for (final chunk in res) {
      chunks.addAll(chunk);
    }
    return chunks;
  } finally {
    client.close();
  }
}
