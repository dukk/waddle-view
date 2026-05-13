import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddlectl/secret_bundle_codec.dart';

void main() {
  test('encode without test overrides round-trips', () async {
    final blob = await encodeSecretBundle({'k': 'v'}, 'unique-password-xyz');
    expect(blob.length >= 53, isTrue);
    expect(await decodeSecretBundle(blob, 'unique-password-xyz'), {'k': 'v'});
  });

  test('round-trip with fixed salt and nonce', () async {
    final salt = Uint8List.fromList(
      List<int>.filled(kSecretBundleSaltBytes, 3),
    );
    final nonce = Uint8List.fromList(List<int>.filled(12, 7));
    final random = Random(42);
    final entries = {'a': 'one', 'token:foo': 'bar'};
    final blob = await encodeSecretBundle(
      entries,
      'correct horse battery staple',
      randomForTest: random,
      saltForTest: salt,
      nonceForTest: nonce,
    );
    final back = await decodeSecretBundle(blob, 'correct horse battery staple');
    expect(back, entries);
  });

  test('wrong password throws FormatException', () async {
    final salt = Uint8List.fromList(
      List<int>.filled(kSecretBundleSaltBytes, 1),
    );
    final nonce = Uint8List.fromList(List<int>.filled(12, 2));
    final blob = await encodeSecretBundle(
      {'k': 'v'},
      'secret-one',
      randomForTest: Random(1),
      saltForTest: salt,
      nonceForTest: nonce,
    );
    await expectLater(
      decodeSecretBundle(blob, 'secret-two'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'wrong password or corrupted bundle',
        ),
      ),
    );
  });

  test('tampered ciphertext fails', () async {
    final salt = Uint8List.fromList(
      List<int>.filled(kSecretBundleSaltBytes, 4),
    );
    final nonce = Uint8List.fromList(List<int>.filled(12, 5));
    final blob = await encodeSecretBundle(
      {'x': 'y'},
      'pw',
      randomForTest: Random(0),
      saltForTest: salt,
      nonceForTest: nonce,
    );
    blob[blob.length - 5] ^= 0xFF;
    await expectLater(
      decodeSecretBundle(blob, 'pw'),
      throwsA(isA<FormatException>()),
    );
  });

  test('empty password rejected on encode', () async {
    await expectLater(
      encodeSecretBundle({}, ''),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('empty map round-trip', () async {
    final salt = Uint8List.fromList(
      List<int>.filled(kSecretBundleSaltBytes, 9),
    );
    final nonce = Uint8List.fromList(List<int>.filled(12, 8));
    final blob = await encodeSecretBundle(
      {},
      'p',
      randomForTest: Random(99),
      saltForTest: salt,
      nonceForTest: nonce,
    );
    expect(await decodeSecretBundle(blob, 'p'), isEmpty);
  });

  test('encode rejects wrong salt length', () async {
    await expectLater(
      encodeSecretBundle({}, 'p', saltForTest: Uint8List(5)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('encode rejects wrong nonce length', () async {
    await expectLater(
      encodeSecretBundle(
        {},
        'p',
        saltForTest: Uint8List.fromList(List<int>.filled(16, 1)),
        nonceForTest: Uint8List(5),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('decode rejects empty password', () async {
    await expectLater(
      decodeSecretBundle(Uint8List(60), ''),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('decode rejects bundle too short', () async {
    await expectLater(
      decodeSecretBundle(Uint8List(10), 'pw'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'bundle too short',
        ),
      ),
    );
  });

  test('decode rejects invalid magic', () async {
    await expectLater(
      decodeSecretBundle(Uint8List(60), 'pw'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'invalid bundle magic',
        ),
      ),
    );
  });

  test('decode rejects unsupported file format version', () async {
    final salt = Uint8List.fromList(List<int>.filled(16, 2));
    final nonce = Uint8List.fromList(List<int>.filled(12, 3));
    final blob = Uint8List.fromList(
      await encodeSecretBundle(
        {'z': 'q'},
        'pw',
        randomForTest: Random(2),
        saltForTest: salt,
        nonceForTest: nonce,
      ),
    );
    blob[8] = 99;
    await expectLater(
      decodeSecretBundle(blob, 'pw'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('format version'),
        ),
      ),
    );
  });

  group('parseSecretBundlePayload', () {
    test('rejects non-map root', () {
      expect(
        () => parseSecretBundlePayload(<Object?>[]),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported payload v', () {
      expect(
        () => parseSecretBundlePayload({'v': 2, 'entries': <String, Object>{}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-map entries', () {
      expect(
        () => parseSecretBundlePayload({'v': 1, 'entries': <Object>[]}),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips non-string and empty values', () {
      expect(
        parseSecretBundlePayload({
          'v': 1,
          'entries': {'a': 1, 'b': '', 'c': 'ok'},
        }),
        {'c': 'ok'},
      );
    });
  });
}
