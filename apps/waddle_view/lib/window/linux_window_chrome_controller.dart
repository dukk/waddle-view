import 'package:window_manager/window_manager.dart';

import 'startup_window_policy.dart';
import 'window_chrome_controller.dart';

class LinuxWindowChromeController implements WindowChromeController {
  @override
  Future<void> initialize() async {
    await windowManager.ensureInitialized();
  }

  @override
  Future<void> applyStartupPolicy(StartupWindowPolicy policy) async {
    if (!policy.shouldMaximize) {
      return;
    }
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(fullScreen: true),
      () async {
        await windowManager.show();
      },
    );
  }
}
