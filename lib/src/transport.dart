import 'dart:io';
import 'dart:typed_data';


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
  final HttpClient _httpClient;

  IOClientTransport() : _httpClient = HttpClient() ..idleTimeout = Duration.zero;

  @override
  Future<TransportResponse> post(
    String url,
    String contentType,
    Uint8List body,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse(url);
    final request = await _httpClient.postUrl(uri);
    request.headers.set('Content-Type', contentType);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.add(body);
    final response = await request.close();
    final builder = BytesBuilder();
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return TransportResponse(
      status: response.statusCode,
      body: builder.toBytes(),
    );
  }

  void close() => _httpClient.close();
}
