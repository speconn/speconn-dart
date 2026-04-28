import 'dart:typed_data';
import 'package:http/http.dart' as http;

abstract class Transport {
  Future<TransportResponse> post(
    String url,
    String contentType,
    Uint8List body,
    Map<String, String> headers,
  );
}

class TransportResponse {
  final int status;
  final Uint8List body;

  const TransportResponse({required this.status, required this.body});
}

class IOClientTransport implements Transport {
  final http.Client _httpClient;

  IOClientTransport() : _httpClient = http.Client();

  @override
  Future<TransportResponse> post(
    String url,
    String contentType,
    Uint8List body,
    Map<String, String> headers,
  ) async {
    final req = http.Request('POST', Uri.parse(url));
    req.headers['Content-Type'] = contentType;
    req.headers.addAll(headers);
    req.bodyBytes = body;
    final resp = await _httpClient.send(req);
    final respBody = await resp.stream.toBytes();
    return TransportResponse(
      status: resp.statusCode,
      body: Uint8List.fromList(respBody),
    );
  }

  void close() => _httpClient.close();
}
