import 'startup_window_policy.dart';

abstract class WindowChromeController {
  Future<void> initialize();

  Future<void> applyStartupPolicy(StartupWindowPolicy policy);
}
