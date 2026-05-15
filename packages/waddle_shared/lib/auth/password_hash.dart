import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 password hashing for operator accounts (stored in SQLite).
const int kPasswordHashIterations = 210000;
const int kPasswordSaltBytes = 16;
const String kPasswordHashPrefix = 'pbkdf2-sha256';

/// Generates a new salted hash string: `pbkdf2-sha256$iterations$base64(salt)$base64(hash)`.
String hashPassword(String password) {
  final salt = _randomSalt();
  final hash = _derive(password, salt);
  return '$kPasswordHashPrefix\$${kPasswordHashIterations}\$'
      '${base64Encode(salt)}\$${base64Encode(hash)}';
}

/// Constant-time aware verify (compares derived bytes in fixed time).
bool verifyPassword(String password, String stored) {
  final parts = stored.split('\$');
  if (parts.length != 4 || parts[0] != kPasswordHashPrefix) {
    return false;
  }
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) {
    return false;
  }
  Uint8List salt;
  Uint8List expected;
  try {
    salt = Uint8List.fromList(base64Decode(parts[2]));
    expected = Uint8List.fromList(base64Decode(parts[3]));
  } catch (_) {
    return false;
  }
  final actual = _derive(password, salt, iterations: iterations);
  if (actual.length != expected.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < actual.length; i++) {
    diff |= actual[i] ^ expected[i];
  }
  return diff == 0;
}

Uint8List _derive(String password, Uint8List salt, {int? iterations}) {
  final it = iterations ?? kPasswordHashIterations;
  final key = utf8.encode(password);
  return _pbkdf2Sha256(key, salt, it, 32);
}

Uint8List _randomSalt() {
  final rnd = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(kPasswordSaltBytes, (_) => rnd.nextInt(256)),
  );
}

/// Minimal PBKDF2-HMAC-SHA256 (RFC 8018) using package:crypto.
Uint8List _pbkdf2Sha256(
  List<int> password,
  Uint8List salt,
  int iterations,
  int length,
) {
  final hmac = Hmac(sha256, password);
  final blocks = (length + 31) ~/ 32;
  final out = BytesBuilder(copy: false);
  for (var block = 1; block <= blocks; block++) {
    final blockSalt = BytesBuilder(copy: false)
      ..add(salt)
      ..addByte(block >> 24)
      ..addByte(block >> 16)
      ..addByte(block >> 8)
      ..addByte(block);
    var u = hmac.convert(blockSalt.toBytes()).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.add(t);
  }
  return Uint8List.fromList(out.toBytes().sublist(0, length));
}
