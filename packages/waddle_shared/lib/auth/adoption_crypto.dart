import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'adoption_challenge_format.dart';

const _crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Generates a URL-safe random nonce for adoption challenges.
String generateAdoptionNonce() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes);
}

/// Eight-character Crockford base32 challenge shown on the kiosk.
String deriveAdoptionChallengeCode({
  required String instanceId,
  required String identifier,
  required int issuedAtMs,
  required String nonce,
}) {
  final message = 'adoption-challenge-v1|$identifier|$issuedAtMs|$nonce';
  final digest = Hmac(sha256, utf8.encode(instanceId))
      .convert(utf8.encode(message));
  return _firstCrockfordChars(digest.bytes, 8);
}

/// Opaque bearer API key returned after successful adoption confirm.
String deriveAdoptionApiKey({
  required String instanceId,
  required String challengeCode,
  required String identifier,
}) {
  final normalized = normalizeAdoptionChallengeCode(challengeCode);
  final message = 'adoption-api-key-v1|$normalized|$identifier';
  final digest =
      Hmac(sha256, utf8.encode(instanceId)).convert(utf8.encode(message));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}

String hashAdoptionApiKey(String apiKey) {
  return base64.encode(sha256.convert(utf8.encode(apiKey)).bytes);
}

String hashAdoptionChallengeCode(String challengeCode) {
  final normalized = normalizeAdoptionChallengeCode(challengeCode);
  return base64.encode(sha256.convert(utf8.encode(normalized)).bytes);
}

bool constantTimeStringEquals(String a, String b) {
  if (a.length != b.length) {
    return false;
  }
  var acc = 0;
  for (var i = 0; i < a.length; i++) {
    acc |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return acc == 0;
}

String _firstCrockfordChars(List<int> bytes, int count) {
  var buffer = 0;
  var bits = 0;
  final out = StringBuffer();
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5 && out.length < count) {
      bits -= 5;
      final index = (buffer >> bits) & 31;
      out.write(_crockfordAlphabet[index]);
    }
    if (out.length >= count) {
      break;
    }
  }
  while (out.length < count) {
    buffer <<= 8;
    bits += 8;
    final index = (buffer >> (bits - 5)) & 31;
    out.write(_crockfordAlphabet[index]);
    bits -= 5;
  }
  return out.toString();
}
