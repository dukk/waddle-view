import 'package:test/test.dart';
import 'package:waddle_shared/config/provider_access_token_env.dart';

void main() {
  test('readMicrosoftGraphClientIdFromEnvMap trims', () {
    expect(
      readMicrosoftGraphClientIdFromEnvMap({
        waddleMicrosoftGraphClientIdEnv: '  ms-id  ',
      }),
      'ms-id',
    );
    expect(readMicrosoftGraphClientIdFromEnvMap({}), isNull);
  });

  test('readGoogleClientIdFromEnvMap trims', () {
    expect(
      readGoogleClientIdFromEnvMap({
        waddleGoogleClientIdEnv: '  g-id  ',
      }),
      'g-id',
    );
    expect(readGoogleClientIdFromEnvMap({}), isNull);
  });
}
