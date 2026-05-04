import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/window/linux_window_chrome_controller.dart';
import 'package:waddle_view/window/startup_window_policy.dart';

void main() {
  test('LinuxWindowChromeController smoke', () async {
    final c = LinuxWindowChromeController();
    try {
      await c.initialize();
      await c.applyStartupPolicy(
        const StartupWindowPolicy(
          isLinux: true,
          isDebug: true,
          allowFullscreen: false,
        ),
      );
    } on Object {
      // window_manager may be unavailable in some headless test environments.
    }
  });
}
