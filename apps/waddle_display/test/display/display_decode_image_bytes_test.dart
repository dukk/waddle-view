import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/display_decode_image_bytes.dart';

/// Valid 1×1 transparent PNG.
final Uint8List _tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

void main() {
  test('canDecodeDisplayImageBytes returns false for empty bytes', () async {
    expect(await canDecodeDisplayImageBytes(Uint8List(0)), isFalse);
  });

  test('canDecodeDisplayImageBytes returns false for corrupt bytes', () async {
    expect(
      await canDecodeDisplayImageBytes(Uint8List.fromList([1, 2, 3, 4])),
      isFalse,
    );
  });

  test('canDecodeDisplayImageBytes returns true for valid PNG', () async {
    expect(await canDecodeDisplayImageBytes(_tinyPng), isTrue);
  });
}
