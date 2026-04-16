// Stub for unsupported platforms
Stream<String> ssePost(String url, Map<String, dynamic> body, String? token) {
  throw UnsupportedError('SSE not supported on this platform');
}
