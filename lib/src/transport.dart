import 'dart:typed_data';
import 'package:http/http.dart' as http;

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

/// HttpClient is the type Speconn expects HTTP clients to implement.
typedef HttpClient = Future<HttpResponse> Function(HttpRequest request);

/// Default HttpClient implementation using package:http.
HttpClient createHttpClient() {
  return (request) async {
    final client = http.Client();
    try {
      final req = http.Request(request.method, Uri.parse(request.url));
      req.headers.addAll(request.headers);
      req.bodyBytes = request.body;
      final resp = await client.send(req);
      final body = Uint8List.fromList(await resp.stream.toBytes());
      return HttpResponse(status: resp.statusCode, body: body);
    } finally {
      client.close();
    }
  };
}
