import 'package:window_manager/window_manager.dart';

import '../debug/app_debug_log.dart';
import 'startup_window_policy.dart';
import 'window_chrome_controller.dart';

class LinuxWindowChromeController implements WindowChromeController {
  @override
  Future<void> initialize() async {
    AppDebugLog.window('LinuxWindowChromeController.initialize');
    await windowManager.ensureInitialized();
  }

  @override
  Future<void> applyStartupPolicy(StartupWindowPolicy policy) async {
    if (!policy.shouldMaximize) {
      AppDebugLog.window('applyStartupPolicy: skip (shouldMaximize=false)');
      return;
    }
    AppDebugLog.window('applyStartupPolicy: fullscreen when ready');
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(fullScreen: true),
      () async {
        await windowManager.show();
      },
    );
  }
}
