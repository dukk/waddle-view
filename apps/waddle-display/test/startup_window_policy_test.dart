import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/window/startup_window_policy.dart';

void main() {
  test('maximize only on linux non-debug when allowed', () {
    expect(
      const StartupWindowPolicy(
        isLinux: true,
        isDebug: false,
        allowFullscreen: true,
      ).shouldMaximize,
      isTrue,
    );
    expect(
      const StartupWindowPolicy(
        isLinux: true,
        isDebug: true,
        allowFullscreen: true,
      ).shouldMaximize,
      isFalse,
    );
    expect(
      const StartupWindowPolicy(
        isLinux: false,
        isDebug: false,
        allowFullscreen: true,
      ).shouldMaximize,
      isFalse,
    );
    expect(
      const StartupWindowPolicy(
        isLinux: true,
        isDebug: false,
        allowFullscreen: false,
      ).shouldMaximize,
      isFalse,
    );
  });
}
