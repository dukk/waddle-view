import 'package:test/test.dart';
import 'package:waddle_shared/auth/password_hash.dart';

void main() {
  test('hash and verify round-trip', () {
    final stored = hashPassword('s3cret!');
    expect(verifyPassword('s3cret!', stored), isTrue);
    expect(verifyPassword('wrong', stored), isFalse);
  });

  test('reject malformed stored hash', () {
    expect(verifyPassword('x', 'not-a-hash'), isFalse);
  });

  test('reject hash with wrong password', () {
    final stored = hashPassword('correct');
    expect(verifyPassword('wrong', stored), isFalse);
  });
}
