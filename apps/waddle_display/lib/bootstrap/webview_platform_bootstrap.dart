import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'webview_platform_register_stub.dart'
    if (dart.library.io) 'webview_platform_register_io.dart' as platform_register;

/// Ensures [WebViewPlatform.instance] is set on Windows and Linux before any
/// [WebViewController] is created.
///
/// [webview_flutter] only bundles Android / iOS / macOS implementations; desktop
/// targets rely on [webview_win_floating] (`implements: webview_flutter`). The
/// plugin's method channel must not be touched until after
/// [WidgetsFlutterBinding.ensureInitialized] — importing
/// `package:webview_win_floating/...` earlier triggers a static `init` call and
/// [MissingPluginException].
Future<void> ensureEmbeddedWebViewPlatform() async {
  if (_bootstrapComplete) {
    return;
  }
  _bootstrapComplete = true;

  if (debugForceEmbeddedWebViewUnavailable) {
    return;
  }
  if (kIsWeb) {
    return;
  }
  if (!Platform.isWindows && !Platform.isLinux) {
    return;
  }
  if (WebViewPlatform.instance != null) {
    _nativePluginVerified = true;
    return;
  }

  platform_register.registerDesktopWebViewPlatform();
  _nativePluginVerified =
      await platform_register.verifyDesktopWebViewNativePlugin();
}

var _bootstrapComplete = false;
var _nativePluginVerified = false;

/// When true (tests only), pretends no WebView platform is available.
@visibleForTesting
bool debugForceEmbeddedWebViewUnavailable = false;

bool _requiresDesktopNativePlugin() =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux);

/// Whether [WebViewController] can be constructed on this runtime.
bool get isEmbeddedWebViewAvailable {
  if (debugForceEmbeddedWebViewUnavailable) {
    return false;
  }
  if (WebViewPlatform.instance == null) {
    return false;
  }
  if (_requiresDesktopNativePlugin() && !_nativePluginVerified) {
    return false;
  }
  return true;
}

String embeddedWebViewUnavailableMessage() =>
    'Embedded web pages are not supported on ${defaultTargetPlatform.name}. '
    'Use Android, iOS, macOS, Windows, or Linux with webview_win_floating.';

@visibleForTesting
void resetEmbeddedWebViewBootstrapForTest() {
  _bootstrapComplete = false;
  _nativePluginVerified = false;
}
