import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/config/saas_env.dart';

void main() {
  test('readSaasModeEnabled is true when env is 1', () {
    expect(readSaasModeEnabled({kDisplaySaasModeEnv: '1'}), isTrue);
    expect(readSaasModeEnabled({}), isFalse);
  });

  test('readSaasApiUrl returns trimmed url', () {
    expect(
      readSaasApiUrl({kDisplaySaasApiUrlEnv: ' http://localhost:8080 '}),
      'http://localhost:8080',
    );
  });
}
