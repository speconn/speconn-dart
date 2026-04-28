import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'transport.dart';

class DioTransport extends SpeconnTransport {
  final dio.Dio _dio;
  final bool _ownsDio;

  DioTransport([dio.Dio? instance])
      : _dio = instance ?? dio.Dio(),
        _ownsDio = instance == null;

  @override
  Future<HttpResponse> send(HttpRequest request) async {
    final resp = await _dio.request<dynamic>(
      request.url,
      data: Stream.fromIterable([request.body]),
      options: dio.Options(
        method: request.method,
        headers: request.headers,
        responseType: dio.ResponseType.bytes,
      ),
    );
    return HttpResponse(
      status: resp.statusCode ?? 0,
      body: Uint8List.fromList(resp.data as List<int>),
    );
  }

  @override
  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }
}
