import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// ASCII file magic for waddlectl encrypted secret bundles.
const kSecretBundleMagic = 'WADSECB1';

/// Current on-disk format version (single byte after magic).
const kSecretBundleFormatVersion = 1;

/// Payload JSON schema version inside decrypted plaintext.
const kSecretBundlePayloadVersion = 1;

/// Salt length for PBKDF2-HMAC-SHA256.
const kSecretBundleSaltBytes = 16;

/// PBKDF2 iteration count (~100–300ms typical dev hardware; tunable with care).
const kSecretBundlePbkdf2Iterations = 310000;

final Pbkdf2 _pbkdf2 = Pbkdf2.hmacSha256(
  iterations: kSecretBundlePbkdf2Iterations,
  bits: 256,
);

final AesGcm _aes = AesGcm.with256bits();

/// Encrypts [entries] into an opaque binary blob (magic, version, salt, AEAD).
Future<Uint8List> encodeSecretBundle(
  Map<String, String> entries,
  String password, {
  Random? randomForTest,
  Uint8List? saltForTest,
  Uint8List? nonceForTest,
}) async {
  if (password.isEmpty) {
    throw ArgumentError.value(password, 'password', 'must not be empty');
  }
  final random = randomForTest ?? Random.secure();
  final salt =
      saltForTest ??
      Uint8List.fromList(
        List<int>.generate(kSecretBundleSaltBytes, (_) => random.nextInt(256)),
      );
  if (salt.length != kSecretBundleSaltBytes) {
    throw ArgumentError.value(salt.length, 'salt', 'wrong length');
  }

  final secretKey = await _pbkdf2.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );

  final payload = utf8.encode(
    jsonEncode({'v': kSecretBundlePayloadVersion, 'entries': entries}),
  );

  final nonce = nonceForTest;
  if (nonce != null && nonce.length != _aes.nonceLength) {
    throw ArgumentError.value(
      nonce.length,
      'nonceForTest',
      'expected ${_aes.nonceLength} bytes',
    );
  }

  final box = await _aes.encrypt(payload, secretKey: secretKey, nonce: nonce);

  final body = box.concatenation();
  final out = BytesBuilder(copy: false);
  out.add(utf8.encode(kSecretBundleMagic));
  out.addByte(kSecretBundleFormatVersion);
  out.add(salt);
  out.add(body);
  return out.takeBytes();
}

/// Decrypts a blob from [encodeSecretBundle]; returns the entries map.
Future<Map<String, String>> decodeSecretBundle(
  Uint8List bytes,
  String password,
) async {
  if (password.isEmpty) {
    throw ArgumentError.value(password, 'password', 'must not be empty');
  }
  final minLen =
      utf8.encode(kSecretBundleMagic).length +
      1 +
      kSecretBundleSaltBytes +
      _aes.nonceLength +
      _aes.macAlgorithm.macLength;
  if (bytes.length < minLen) {
    throw const FormatException('bundle too short');
  }

  final magicLen = utf8.encode(kSecretBundleMagic).length;
  final magic = utf8.decode(bytes.sublist(0, magicLen));
  if (magic != kSecretBundleMagic) {
    throw const FormatException('invalid bundle magic');
  }
  final ver = bytes[magicLen];
  if (ver != kSecretBundleFormatVersion) {
    throw FormatException('unsupported bundle format version: $ver');
  }

  final saltStart = magicLen + 1;
  final salt = bytes.sublist(saltStart, saltStart + kSecretBundleSaltBytes);
  final body = bytes.sublist(saltStart + kSecretBundleSaltBytes);

  final secretKey = await _pbkdf2.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );

  final box = SecretBox.fromConcatenation(
    body,
    nonceLength: _aes.nonceLength,
    macLength: _aes.macAlgorithm.macLength,
  );

  late final List<int> clear;
  try {
    clear = await _aes.decrypt(box, secretKey: secretKey);
  } on SecretBoxAuthenticationError {
    throw const FormatException('wrong password or corrupted bundle');
  }

  final decoded = jsonDecode(utf8.decode(clear));
  return parseSecretBundlePayload(decoded);
}

/// Parses decrypted JSON; exposed for unit tests.
Map<String, String> parseSecretBundlePayload(Object? decoded) {
  if (decoded is! Map) {
    throw const FormatException('invalid bundle payload');
  }
  final map = decoded.cast<String, Object?>();
  final v = map['v'];
  if (v != kSecretBundlePayloadVersion) {
    throw FormatException('unsupported payload version: $v');
  }
  final raw = map['entries'];
  if (raw is! Map) {
    throw const FormatException('invalid entries in bundle');
  }
  final out = <String, String>{};
  for (final e in raw.entries) {
    final key = e.key;
    final val = e.value;
    if (val is! String || val.isEmpty) {
      continue;
    }
    out[key] = val;
  }
  return out;
}
