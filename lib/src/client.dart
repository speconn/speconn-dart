import 'dart:convert';
import 'dart:io';
import 'error.dart';

class UnaryClient {
  final String baseUrl;
  final HttpClient _httpClient;

  UnaryClient(this.baseUrl) : _httpClient = HttpClient();

  Future<T> call<T>(String path, Map<String, dynamic> req, T Function(Map<String, dynamic>) fromJson) async {
    final url = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final httpClientRequest = await _httpClient.postUrl(url);
    httpClientRequest.headers.set('Content-Type', 'application/json');
    httpClientRequest.write(jsonEncode(req));

    final response = await httpClientRequest.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      final err = jsonDecode(body) as Map<String, dynamic>;
      throw SpeconnError(err['code'] as String? ?? 'unknown', err['message'] as String? ?? '');
    }

    return fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  void close() => _httpClient.close();
}

class StreamClient {
  final String baseUrl;
  final HttpClient _httpClient;

  StreamClient(this.baseUrl) : _httpClient = HttpClient();

  Stream<T> call<T>(String path, Map<String, dynamic> req, T Function(Map<String, dynamic>) fromJson) async* {
    final url = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final httpClientRequest = await _httpClient.postUrl(url);
    httpClientRequest.headers.set('Content-Type', 'application/connect+json');
    httpClientRequest.headers.set('Connect-Protocol-Version', '1');
    httpClientRequest.write(jsonEncode(req));

    final response = await httpClientRequest.close();

    final chunks = <int>[];
    await for (final chunk in response) {
      chunks.addAll(chunk);

      while (chunks.length >= 5) {
        final flags = chunks[0];
        final length = (chunks[1] << 24) | (chunks[2] << 16) | (chunks[3] << 8) | chunks[4];
        if (chunks.length < 5 + length) break;

        final payload = chunks.sublist(5, 5 + length);
        chunks.removeRange(0, 5 + length);

        if (flags & 0x02 != 0) {
          final trailer = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
          final error = trailer['error'] as Map<String, dynamic>?;
          if (error != null) {
            throw SpeconnError(error['code'] as String? ?? 'unknown', error['message'] as String? ?? '');
          }
          return;
        }

        yield fromJson(jsonDecode(utf8.decode(payload)) as Map<String, dynamic>);
      }
    }
  }

  void close() => _httpClient.close();
}
