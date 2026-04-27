import 'dart:convert';
import 'dart:typed_data';

import 'envelope.dart';
import 'error.dart';
import 'transport.dart';

class UnaryClient {
  final String baseUrl;
  final Transport _transport;
  final bool _ownsTransport;

  UnaryClient._(this.baseUrl, this._transport, this._ownsTransport);

  factory UnaryClient(String baseUrl, {Transport? transport}) {
    final t = transport ?? IOClientTransport();
    return UnaryClient._(
      baseUrl.replaceAll(RegExp(r'/+$'), ''),
      t,
      transport == null,
    );
  }

  Future<T> call<T>(
    String path,
    Map<String, dynamic> req,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final url = '$baseUrl$path';
    final body = Uint8List.fromList(utf8.encode(jsonEncode(req)));

    final resp = await _transport.post(
      url,
      'application/json',
      body,
      const {},
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
    String path,
    Map<String, dynamic> req,
    T Function(Map<String, dynamic>) fromJson,
  ) async* {
    final url = '$baseUrl$path';
    final body = Uint8List.fromList(utf8.encode(jsonEncode(req)));

    final resp = await _transport.post(
      url,
      'application/connect+json',
      body,
      {'connect-protocol-version': '1'},
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

  void close() {
    if (_ownsTransport) {
      (_transport as IOClientTransport).close();
    }
  }

  static Map<String, dynamic> _parseBody(Uint8List body) {
    return jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
  }
}
