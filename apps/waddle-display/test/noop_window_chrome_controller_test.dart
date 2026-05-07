import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/window/noop_window_chrome_controller.dart';
import 'package:waddle_display/window/startup_window_policy.dart';

void main() {
  test('NoOpWindowChromeController completes', () async {
    final c = NoOpWindowChromeController();
    await c.initialize();
    await c.applyStartupPolicy(
      const StartupWindowPolicy(
        isLinux: false,
        isDebug: true,
        allowFullscreen: false,
      ),
    );
  });
}
