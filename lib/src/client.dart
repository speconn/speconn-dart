import 'dart:typed_data';

import 'envelope.dart';
import 'error.dart';
import 'transport.dart';
import 'transport_http.dart';
import 'package:specodec/specodec.dart';


String _getContentType(Map<String, String> headers) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'content-type') return entry.value;
  }
  return 'application/json';
}

String _getAccept(Map<String, String> headers) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'accept') return entry.value;
  }
  return _getContentType(headers);
}

String _extractFormat(String mime) =>
    mime.contains('msgpack') ? 'msgpack' : 'json';

String _formatToMime(String fmt, {bool stream = false}) {
  final base = fmt == 'msgpack' ? 'msgpack' : 'json';
  return stream ? 'application/connect+$base' : 'application/$base';
}

class SpeconnClient {
  final String _url;
  final SpeconnTransport _transport;

  SpeconnClient(String baseUrl, String path, {SpeconnTransport? transport})
      : _url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path',
        _transport = transport ?? HttpTransport();

  Future<T> call<T>(
    SpecCodec<T> reqCodec,
    T req,
    SpecCodec<T> resCodec,
    {Map<String, String> headers = const {}}
  ) async {
    final reqFmt = _extractFormat(_getContentType(headers));
    final resFmt = _extractFormat(_getAccept(headers));

    final body = respond(reqCodec, req, reqFmt).body;

    final resp = await _transport.send(
      HttpRequest(url: _url, method: 'POST', headers: headers, body: body),
    );
    if (resp.status >= 400) {
      throw _parseError(resp.body);
    }
    return dispatch(resCodec, resp.body, resFmt);
  }

  Stream<T> stream<T>(
    SpecCodec<T> reqCodec,
    T req,
    SpecCodec<T> resCodec,
    {Map<String, String> headers = const {}}
  ) async* {
    final reqFmt = _extractFormat(_getContentType(headers));
    final resFmt = _extractFormat(_getAccept(headers));

    final streamHeaders = headers.keys.any((k) => k.toLowerCase() == 'connect-protocol-version')
        ? headers
        : {...headers, 'connect-protocol-version': '1', 'content-type': _formatToMime(reqFmt, stream: true)};

    final body = respond(reqCodec, req, reqFmt).body;

    final resp = await _transport.send(
      HttpRequest(url: _url, method: 'POST', headers: streamHeaders, body: body),
    );
    if (resp.status >= 400) {
      throw _parseError(resp.body);
    }
    var pos = 0;
    while (pos < resp.body.length) {
      if (resp.body.length - pos < 5) break;
      final remaining = Uint8List.sublistView(resp.body, pos);
      final (:flags, :payload) = decodeEnvelope(remaining);
      pos += 5 + payload.length;
      if (flags & flagEndStream != 0) {
        if (payload.isNotEmpty) throw SpeconnError.decode(payload, resFmt);
        return;
      }
      yield dispatch(resCodec, payload, resFmt);
    }
  }

  static SpeconnError _parseError(Uint8List body) {
    if (body.isEmpty) return SpeconnError(SpeconnError.unknown, 'empty error body');
    return SpeconnError.decode(body, 'json');
  }
}
