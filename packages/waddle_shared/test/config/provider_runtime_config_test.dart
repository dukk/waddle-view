import 'package:test/test.dart';

import 'package:waddle_shared/config/provider_runtime_config.dart';

void main() {
  test('describeForLogs redacts token', () {
    const c = ProviderRuntimeConfig(
      providerId: 'p',
      integrationType: 't',
      pollSeconds: 1,
      accessToken: 'secret',
    );
    expect(c.describeForLogs(), isNot(contains('secret')));
  });
}
