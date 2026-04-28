import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'transport.dart';

class HttpTransport extends SpeconnTransport {
  http.Client? _client;
  final bool _ownsClient;

  HttpTransport([http.Client? client])
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  @override
  Future<HttpResponse> send(HttpRequest request) async {
    final client = _client!;
    final req = http.Request(request.method, Uri.parse(request.url));
    req.headers.addAll(request.headers);
    req.bodyBytes = request.body;
    final resp = await client.send(req);
    final body = Uint8List.fromList(await resp.stream.toBytes());
    return HttpResponse(status: resp.statusCode, body: body);
  }

  @override
  void close() {
    if (_ownsClient) {
      _client?.close();
      _client = null;
    }
  }
}
