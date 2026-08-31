// test_tink.dart —— unit tests for tink.dart. Run: dart run test_tink.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'tink.dart';

int failures = 0;

void check(bool cond, String name) {
  if (cond) {
    print('[PASS] $name');
  } else {
    failures++;
    print('[FAIL] $name');
  }
}

void main() {
  // crc32 check vector
  check(crc32(Uint8List.fromList(ascii.encode('123456789'))) == 0xCBF43926, 'crc32 vector');

  // frame roundtrip
  final p = Uint8List.fromList([1, 2, 3]);
  final frame = frameEncode(p);
  check(frame.length == p.length + 8, 'frame length');
  final got = frameNext(frame, 0);
  check(got != null, 'frame present');
  if (got != null) {
    check(got.next == frame.length, 'frame next == length');
    check(got.payload.length == p.length && got.payload[0] == p[0] &&
        got.payload[1] == p[1] && got.payload[2] == p[2], 'frame payload roundtrip');
  }

  // empty frame roundtrip
  final fe = frameEncode(Uint8List(0));
  final ge = frameNext(fe, 0);
  check(ge != null && ge.next == fe.length && ge.payload.isEmpty, 'empty frame roundtrip');

  // CRC tamper rejected
  final ft = frameEncode(p);
  ft[4] += 1; // tamper payload[0]
  check(frameNext(ft, 0) == null, 'crc tamper rejected');

  // frameSkip matches length
  final fs = frameEncode(p);
  check(frameSkip(fs, 0) == fs.length, 'frameSkip matches length');

  // out of bounds
  check(frameNext(frame, frame.length) == null, 'frameNext out of bounds');
  check(frameSkip(frame, frame.length) == null, 'frameSkip out of bounds');
  check(frameNext(Uint8List(0), 0) == null, 'frameNext empty input');

  if (failures > 0) {
    print('$failures checks FAILED');
    exit(1);
  }
  print('all tests passed');
}