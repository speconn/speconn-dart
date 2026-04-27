import 'dart:typed_data';

const int flagCompressed = 0x01;
const int flagEndStream = 0x02;

Uint8List encodeEnvelope(int flags, Uint8List payload) {
  final buf = Uint8List(5 + payload.length);
  buf[0] = flags;
  buf[1] = (payload.length >> 24) & 0xff;
  buf[2] = (payload.length >> 16) & 0xff;
  buf[3] = (payload.length >> 8) & 0xff;
  buf[4] = payload.length & 0xff;
  buf.setRange(5, 5 + payload.length, payload);
  return buf;
}

({int flags, Uint8List payload}) decodeEnvelope(Uint8List data) {
  if (data.length < 5) {
    throw FormatException(
      'envelope: frame too short (${data.length} bytes)',
    );
  }
  final flags = data[0];
  final length =
      (data[1] << 24) | (data[2] << 16) | (data[3] << 8) | data[4];
  if (data.length < 5 + length) {
    throw FormatException(
      'envelope: expected $length payload bytes, got ${data.length - 5}',
    );
  }
  final payload = Uint8List.sublistView(data, 5, 5 + length);
  return (flags: flags, payload: payload);
}
