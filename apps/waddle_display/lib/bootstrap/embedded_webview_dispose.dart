import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// [webview_win_floating] returns this when [WinWebViewController.dispose] runs
/// after native teardown (app exit, hot restart `init`, or a prior dispose).
bool isBenignEmbeddedWebViewDisposePlatformException(PlatformException error) {
  if (error.code == "webview hasn't created") {
    return true;
  }
  final message = error.message;
  return message != null && message.contains('webview hasn');
}

/// Detaches the desktop native webview for [controller].
///
/// [WebViewController] has no public dispose API; the plugin relies on a
/// [Finalizer]. Call this when dropping a preloaded session or overlay so
/// teardown is deterministic and idempotent dispose races are swallowed.
Future<void> disposeEmbeddedWebViewController(
  WebViewController controller,
) async {
  if (kIsWeb) {
    return;
  }
  if (!Platform.isWindows && !Platform.isLinux) {
    return;
  }
  try {
    final platform = controller.platform;
    final typeName = platform.runtimeType.toString();
    if (typeName.contains('WindowsPlatformWebViewController')) {
      await (platform as dynamic).controller.dispose();
    }
  } on PlatformException catch (error) {
    if (!isBenignEmbeddedWebViewDisposePlatformException(error)) {
      rethrow;
    }
  }
}
