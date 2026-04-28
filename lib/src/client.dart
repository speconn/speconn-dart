import 'dart:convert';
import 'dart:typed_data';

import 'envelope.dart';
import 'error.dart';
import 'transport.dart';
import 'transport_http.dart';

class SpeconnClient {
  final String _url;
  final SpeconnTransport _transport;

  SpeconnClient(String baseUrl, String path, {SpeconnTransport? transport})
      : _url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path',
        _transport = transport ?? HttpTransport();

  Future<T> call<T>(
    Map<String, dynamic> req,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, String> headers = const {},
  }) async {
    final body = Uint8List.fromList(utf8.encode(jsonEncode(req)));
    final reqHeaders = {
      'content-type': 'application/json',
      ...headers,
    };
    final resp = await _transport.send(
      HttpRequest(url: _url, method: 'POST', headers: reqHeaders, body: body),
    );
    if (resp.status >= 400) {
      final err = _parseBody(resp.body);
      throw SpeconnError(
        err['code'] as String? ?? SpeconnError.unknown,
        err['message'] as String? ?? '',
      );
    }
    return fromJson(_parseBody(resp.body));
  }

  Stream<T> stream<T>(
    Map<String, dynamic> req,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, String> headers = const {},
  }) async* {
    final body = Uint8List.fromList(utf8.encode(jsonEncode(req)));
    final reqHeaders = {
      'content-type': 'application/connect+json',
      'connect-protocol-version': '1',
      ...headers,
    };
    final resp = await _transport.send(
      HttpRequest(url: _url, method: 'POST', headers: reqHeaders, body: body),
    );
    if (resp.status >= 400) {
      final err = _parseBody(resp.body);
      throw SpeconnError(
        err['code'] as String? ?? SpeconnError.unknown,
        err['message'] as String? ?? '',
      );
    }
    var pos = 0;
    while (pos < resp.body.length) {
      if (resp.body.length - pos < 5) break;
      final remaining = Uint8List.sublistView(resp.body, pos);
      final (:flags, :payload) = decodeEnvelope(remaining);
      pos += 5 + payload.length;
      if (flags & flagEndStream != 0) {
        final trailer = _parseBody(payload);
        final error = trailer['error'] as Map<String, dynamic>?;
        if (error != null) {
          throw SpeconnError(
            error['code'] as String? ?? SpeconnError.unknown,
            error['message'] as String? ?? '',
          );
        }
        return;
      }
      yield fromJson(_parseBody(payload));
    }
  }

  static Map<String, dynamic> _parseBody(Uint8List body) {
    return jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
  }
}
