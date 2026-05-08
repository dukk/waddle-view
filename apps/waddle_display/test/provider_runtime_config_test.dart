import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/config/provider_runtime_config.dart';

void main() {
  test('describeForLogs redacts token', () {
    const c = ProviderRuntimeConfig(
      providerId: 'p',
      providerType: 't',
      pollSeconds: 1,
      accessToken: 'secret',
    );
    expect(c.describeForLogs(), isNot(contains('secret')));
  });
}
