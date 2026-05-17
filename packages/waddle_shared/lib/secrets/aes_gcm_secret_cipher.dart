import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM: wire format `nonce (12) || ciphertext || tag (16)`.
abstract final class AesGcmSecretCipher {
  static const int dekLength = 32;
  static const int nonceLength = 12;
  static const int tagLength = 16;

  static final AesGcm _algorithm = AesGcm.with256bits();

  static Future<SecretKey> secretKeyFromBytes(List<int> dekBytes) async {
    if (dekBytes.length != dekLength) {
      throw ArgumentError('DEK must be $dekLength bytes');
    }
    return SecretKey(dekBytes);
  }

  static Future<Uint8List> encrypt(
    SecretKey dek,
    Uint8List plaintext,
  ) async {
    final nonce = _randomNonce();
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: dek,
      nonce: nonce,
    );
    final combined = Uint8List(
      nonceLength + box.cipherText.length + tagLength,
    );
    combined.setRange(0, nonceLength, nonce);
    combined.setRange(nonceLength, nonceLength + box.cipherText.length, box.cipherText);
    combined.setRange(
      nonceLength + box.cipherText.length,
      combined.length,
      box.mac.bytes,
    );
    return combined;
  }

  static Future<Uint8List> decrypt(
    SecretKey dek,
    Uint8List wire,
  ) async {
    if (wire.length < nonceLength + tagLength + 1) {
      throw StateError('Invalid ciphertext length');
    }
    final nonce = wire.sublist(0, nonceLength);
    final tagStart = wire.length - tagLength;
    final cipherText = wire.sublist(nonceLength, tagStart);
    final mac = Mac(wire.sublist(tagStart));
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    final plain = await _algorithm.decrypt(box, secretKey: dek);
    return Uint8List.fromList(plain);
  }

  static List<int> _randomNonce() {
    final rnd = Random.secure();
    return List<int>.generate(nonceLength, (_) => rnd.nextInt(256));
  }
}
