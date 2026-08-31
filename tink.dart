// tink.dart —— tink data-flow node frame protocol (universal, language-agnostic).
//
// Frame = [len u32 BE][payload][crc u32 BE]; crc = CRC32-IEEE (0xEDB88320).
// Mirrors std/tink.tie (tie standard library) and the other-language tink
// libraries; pure top-level functions over List<int> (byte vector), IO
// (stdin/stdout) left to the caller. Dart 3, SDK-only, no dependencies.
//
//   final frame = frameEncode([1, 2, 3]);
//   final got = frameNext(frame, 0); // (payload, next)?

import 'dart:typed_data';

/// CRC32-IEEE over a byte vector (bit-loop, no table; matches zlib.crc32).
/// Check vector: crc32(ascii("123456789")) == 0xCBF43926.
int crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (var i = 0; i < data.length; i++) {
    crc ^= data[i];
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Encode a payload into a full frame: [len u32 BE][payload][crc u32 BE].
/// Returns a new Uint8List of payload.length + 8 bytes.
Uint8List frameEncode(Uint8List payload) {
  final out = Uint8List(payload.length + 8);
  final n = payload.length;
  final bd = ByteData.sublistView(out);
  bd.setUint32(0, n, Endian.big);
  out.setRange(4, 4 + n, payload);
  bd.setUint32(4 + n, crc32(payload), Endian.big);
  return out;
}

/// Result of parsing a frame: the payload (a copy) and the position right
/// after the frame (payload length + 8).
class Frame {
  final Uint8List payload;
  final int next;
  const Frame(this.payload, this.next);
}

/// Parse one frame at pos (verifies CRC). Returns a [Frame] on success or
/// null on out-of-bounds / CRC mismatch.
Frame? frameNext(Uint8List bytes, int pos) {
  if (bytes.length < pos + 8) return null;
  final bd = ByteData.sublistView(bytes);
  final n = bd.getUint32(pos, Endian.big);
  final end = pos + 8 + n;
  if (bytes.length < end) return null;
  final payload = Uint8List.sublistView(bytes, pos + 4, pos + 4 + n);
  final want = bd.getUint32(end - 4, Endian.big);
  if (crc32(payload) != want) return null;
  return Frame(Uint8List.fromList(payload), end);
}

/// Skip one frame at pos without copying or verifying (zero-copy).
/// Returns the position after the frame, or null on out-of-bounds.
int? frameSkip(Uint8List bytes, int pos) {
  if (bytes.length < pos + 8) return null;
  final bd = ByteData.sublistView(bytes);
  final n = bd.getUint32(pos, Endian.big);
  final end = pos + 8 + n;
  if (bytes.length < end) return null;
  return end;
}