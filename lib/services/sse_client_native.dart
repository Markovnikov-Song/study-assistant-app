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
        leftover = '';
        for (final line in text.split('\n')) {
          if (line.startsWith('data: ')) {
            ctrl.add(line.substring(6));
          } else if (line.isNotEmpty) {
            leftover = line;
          }
        }
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
