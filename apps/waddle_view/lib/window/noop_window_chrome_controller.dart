import 'startup_window_policy.dart';
import 'window_chrome_controller.dart';

class NoOpWindowChromeController implements WindowChromeController {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> applyStartupPolicy(StartupWindowPolicy policy) async {}
}
