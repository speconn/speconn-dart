import 'dart:typed_data';

class HttpRequest {
  final String url;
  final String method;
  final Map<String, String> headers;
  final Uint8List body;

  const HttpRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
  });
}

class HttpResponse {
  final int status;
  final Uint8List body;

  const HttpResponse({required this.status, required this.body});
}

abstract class SpeconnTransport {
  Future<HttpResponse> send(HttpRequest request);
  void close() {}
}
