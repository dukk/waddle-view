import 'package:flutter/services.dart';
import 'package:webview_win_floating/webview_plugin.dart';

void registerDesktopWebViewPlatform() {
  WindowsWebViewPlatform.registerWith();
}

Future<bool> verifyDesktopWebViewNativePlugin() async {
  try {
    const channel = MethodChannel('webview_win_floating');
    await channel.invokeMethod<bool>('init');
    return true;
  } on MissingPluginException {
    return false;
  }
}
