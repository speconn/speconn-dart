import 'dart:typed_data';

import 'envelope.dart';
import 'error.dart';
import 'transport.dart';
import 'transport_http.dart';
import 'package:specodec/specodec.dart';

class CallOptions {
  final Map<String, String> headers;
  final int? timeoutMs;

  const CallOptions({this.headers = const {}, this.timeoutMs});
}

class Response<T> {
  final T msg;
  final Map<String, String> headers;
  final Map<String, String> trailers;

  Response(this.msg, this.headers, this.trailers);
}

class StreamResponse<T> {
  final Map<String, String> headers;
  Map<String, String> trailers = {};
  final List<T> _msgs = [];

  StreamResponse(this.headers);

  Stream<T> asStream() async* {
    for (final msg in _msgs) {
      yield msg;
    }
  }

  void _addMsg(T msg) {
    _msgs.add(msg);
  }

  void _setTrailers(Map<String, String> t) {
    trailers = t;
  }
}

Map<String, String> _splitHeadersTrailers(
    List<MapEntry<String, String>> rawHeaders, bool isTrailers) {
  final result = <String, String>{};
  for (final entry in rawHeaders) {
    if (isTrailers && entry.key.toLowerCase().startsWith('trailer-')) {
      result[entry.key.substring(8)] = entry.value;
    } else if (!isTrailers && !entry.key.toLowerCase().startsWith('trailer-')) {
      result[entry.key.toLowerCase()] = entry.value;
    }
  }
  return result;
}

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

  Future<Response<T>> call<T>(
    SpecCodec<T> reqCodec,
    T req,
    SpecCodec<T> resCodec,
    {CallOptions options = const CallOptions()}
  ) async {
    final reqFmt = _extractFormat(_getContentType(options.headers));
    final resFmt = _extractFormat(_getAccept(options.headers));

    final body = respond(reqCodec, req, reqFmt).body;

    final resp = await _transport.send(
      HttpRequest(url: _url, method: 'POST', headers: options.headers, body: body),
    );
    if (resp.status >= 400) {
      throw _parseError(resp.body);
    }
    final headers = _splitHeadersTrailers(resp.headers.entries.toList(), false);
    final trailers = _splitHeadersTrailers(resp.headers.entries.toList(), true);
    final msg = dispatch(resCodec, resp.body, resFmt);
    return Response(msg, headers, trailers);
  }

  Future<StreamResponse<T>> stream<T>(
    SpecCodec<T> reqCodec,
    T req,
    SpecCodec<T> resCodec,
    {CallOptions options = const CallOptions()}
  ) async {
    final reqFmt = _extractFormat(_getContentType(options.headers));
    final resFmt = _extractFormat(_getAccept(options.headers));

    final streamHeaders = options.headers.keys.any((k) => k.toLowerCase() == 'connect-protocol-version')
        ? options.headers
        : {...options.headers, 'connect-protocol-version': '1', 'content-type': _formatToMime(reqFmt, stream: true)};

    final body = respond(reqCodec, req, reqFmt).body;

    final resp = await _transport.send(
      HttpRequest(url: _url, method: 'POST', headers: streamHeaders, body: body),
    );
    if (resp.status >= 400) {
      throw _parseError(resp.body);
    }

    final headers = _splitHeadersTrailers(resp.headers.entries.toList(), false);
    final trailers = _splitHeadersTrailers(resp.headers.entries.toList(), true);
    final streamResp = StreamResponse<T>(headers);

    var pos = 0;
    while (pos < resp.body.length) {
      if (resp.body.length - pos < 5) break;
      final remaining = Uint8List.sublistView(resp.body, pos);
      final (:flags, :payload) = decodeEnvelope(remaining);
      pos += 5 + payload.length;
      if (flags & flagEndStream != 0) {
        if (payload.isNotEmpty) throw SpeconnError.decode(payload, resFmt);
        break;
      }
      final msg = dispatch(resCodec, payload, resFmt);
      streamResp._addMsg(msg);
    }

    streamResp._setTrailers(trailers);
    return streamResp;
  }

  static SpeconnError _parseError(Uint8List body) {
    if (body.isEmpty) return SpeconnError(SpeconnError.unknown, 'empty error body');
    return SpeconnError.decode(body, 'json');
  }
}
