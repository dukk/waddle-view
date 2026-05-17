import 'package:test/test.dart';
import 'package:waddle_shared/auth/adoption_crypto.dart';

void main() {
  final instanceId = 'a' * 64;
  const identifier = 'my-laptop';
  const issuedAtMs = 1_700_000_000_000;
  const nonce = 'test-nonce-value';

  test('deriveAdoptionChallengeCode is 8 Crockford chars', () {
    final code = deriveAdoptionChallengeCode(
      instanceId: instanceId,
      identifier: identifier,
      issuedAtMs: issuedAtMs,
      nonce: nonce,
    );
    expect(code.length, 8);
    expect(code, matches(RegExp(r'^[0-9A-HJKMNP-Z]{8}$')));
  });

  test('challenge derivation is deterministic', () {
    final a = deriveAdoptionChallengeCode(
      instanceId: instanceId,
      identifier: identifier,
      issuedAtMs: issuedAtMs,
      nonce: nonce,
    );
    final b = deriveAdoptionChallengeCode(
      instanceId: instanceId,
      identifier: identifier,
      issuedAtMs: issuedAtMs,
      nonce: nonce,
    );
    expect(a, b);
  });

  test('hash accepts hyphenated challenge input', () {
    final challenge = deriveAdoptionChallengeCode(
      instanceId: instanceId,
      identifier: identifier,
      issuedAtMs: issuedAtMs,
      nonce: nonce,
    );
    final formatted =
        '${challenge.substring(0, 4)}-${challenge.substring(4)}';
    expect(
      hashAdoptionChallengeCode(formatted),
      hashAdoptionChallengeCode(challenge),
    );
  });

  test('deriveAdoptionApiKey is stable for normalized challenge', () {
    final challenge = deriveAdoptionChallengeCode(
      instanceId: instanceId,
      identifier: identifier,
      issuedAtMs: issuedAtMs,
      nonce: nonce,
    );
    final keyA = deriveAdoptionApiKey(
      instanceId: instanceId,
      challengeCode: challenge,
      identifier: identifier,
    );
    final keyB = deriveAdoptionApiKey(
      instanceId: instanceId,
      challengeCode: challenge.toLowerCase(),
      identifier: identifier,
    );
    expect(keyA, keyB);
    expect(keyA, isNotEmpty);
  });

  test('hashAdoptionApiKey verifies with constantTimeStringEquals', () {
    final key = deriveAdoptionApiKey(
      instanceId: instanceId,
      challengeCode: 'ABCD2345',
      identifier: identifier,
    );
    final hash = hashAdoptionApiKey(key);
    expect(constantTimeStringEquals(hash, hashAdoptionApiKey(key)), isTrue);
    expect(constantTimeStringEquals(hash, hashAdoptionApiKey('wrong')), isFalse);
  });
}
