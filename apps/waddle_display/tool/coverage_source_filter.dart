/// Which source paths count toward the merged CI coverage gate.
bool includeCoverageSourceFile(String sf, {required String lcovPath}) {
  final norm = sf.replaceAll('\\', '/');
  final lcovNorm = lcovPath.replaceAll('\\', '/');
  if (norm.contains('packages/waddle_plugin_example/')) {
    return false;
  }
  if (norm.contains('packages/waddle_integrations/')) {
    return false;
  }
  if (norm.endsWith('.g.dart')) {
    return false;
  }
  if (norm.endsWith('main.dart')) {
    return false;
  }
  final bareLib = norm.startsWith('lib/') && !norm.contains('packages/');
  final isDisplayLib =
      norm.contains('/apps/waddle_display/lib/') ||
      (bareLib &&
          !lcovNorm.contains('waddle_shared') &&
          !lcovNorm.contains('waddle_plugin_sdk') &&
          !lcovNorm.contains('waddle_integrations'));
  final isSharedLib =
      norm.contains('packages/waddle_shared/lib/') ||
      (bareLib && lcovNorm.contains('waddle_shared'));
  final isPluginSdkLib =
      norm.contains('packages/waddle_plugin_sdk/lib/') ||
      (bareLib && lcovNorm.contains('waddle_plugin_sdk'));
  if (!isDisplayLib && !isSharedLib && !isPluginSdkLib) {
    return false;
  }
  if (norm.endsWith('persistence/tables.dart')) {
    return false;
  }
  if (norm.endsWith('display/screen_rotator.dart')) {
    return false;
  }
  if (norm.endsWith('extensions/screen_widget_registry.dart')) {
    return false;
  }
  return true;
}
