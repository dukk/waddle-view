import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

import '../../../bootstrap/webview_platform_bootstrap.dart';
import 'web_page_config.dart';

/// Thrown when a web page cannot be prepared for display.
class WebPageLoadException implements Exception {
  WebPageLoadException(this.message);

  final String message;

  @override
  String toString() => 'WebPageLoadException: $message';
}

/// A loaded web page ready to attach to [WebViewWidget].
abstract class WebPagePreparedSession {
  WebPageConfig get config;

  Widget buildView();

  Future<double> measureScrollableExtent();

  Future<void> scrollBy(double delta);

  void dispose();
}

typedef WebPageSessionLoader = Future<WebPagePreparedSession> Function(
  ParsedWidgetSpec spec,
  WebPageConfig config,
);

/// Preloads [web_page] slides before the rotator shows them.
class WebPagePrepareCache {
  WebPagePrepareCache._();

  static final WebPagePrepareCache instance = WebPagePrepareCache._();

  /// When set (tests), bypasses platform WebView creation.
  @visibleForTesting
  static WebPageSessionLoader? debugLoader;

  final Map<String, Future<WebPagePreparedSession>> _inFlight = {};
  final Map<String, WebPagePreparedSession> _ready = {};

  Future<void> preload(ParsedWidgetSpec spec) async {
    final config = parseWebPageConfig(spec.config);
    if (config.uri == null ||
        (config.uri!.scheme != 'http' && config.uri!.scheme != 'https')) {
      throw WebPageLoadException('config.url must be http or https');
    }
    final key = webPagePrepareCacheKey(choiceKey: spec.choiceKey, config: config);
    if (_ready.containsKey(key)) {
      return;
    }
    final existing = _inFlight[key];
    if (existing != null) {
      await existing;
      return;
    }
    final loader = debugLoader ?? _loadWithWebView;
    final future = loader(spec, config);
    _inFlight[key] = future;
    try {
      try {
        final session = await future;
        _ready[key] = session;
      } on Object catch (e) {
        _ready[key] = WebPageFailedSession(
          config: config,
          message: _webPagePreloadErrorMessage(e),
        );
      }
    } finally {
      _inFlight.remove(key);
    }
  }

  WebPagePreparedSession? takeReady(ParsedWidgetSpec spec) {
    final config = parseWebPageConfig(spec.config);
    final key = webPagePrepareCacheKey(choiceKey: spec.choiceKey, config: config);
    return _ready.remove(key);
  }

  void disposeAll() {
    for (final session in _ready.values) {
      session.dispose();
    }
    _ready.clear();
    _inFlight.clear();
  }
}

String _webPagePreloadErrorMessage(Object error) {
  if (error is WebPageLoadException) {
    return error.message;
  }
  if (error is MissingPluginException &&
      error.toString().contains('webview_win_floating')) {
    return 'Embedded web view native plugin is not available. '
        'Stop the app, run `flutter clean`, then rebuild (full restart, not hot restart).';
  }
  return error.toString();
}

Future<WebPagePreparedSession> _loadWithWebView(
  ParsedWidgetSpec spec,
  WebPageConfig config,
) async {
  await ensureEmbeddedWebViewPlatform();
  if (!isEmbeddedWebViewAvailable) {
    throw WebPageLoadException(embeddedWebViewUnavailableMessage());
  }

  final uri = config.uri!;
  final loadCompleter = Completer<void>();
  var loadFinished = false;

  final controller = WebViewController();
  await controller.setJavaScriptMode(
    config.javascriptEnabled
        ? JavaScriptMode.unrestricted
        : JavaScriptMode.disabled,
  );
  if (config.userAgent != null) {
    await controller.setUserAgent(config.userAgent!);
  }
  await controller.setNavigationDelegate(
    NavigationDelegate(
      onPageFinished: (_) {
        if (!loadFinished) {
          loadFinished = true;
          if (!loadCompleter.isCompleted) {
            loadCompleter.complete();
          }
        }
      },
      onWebResourceError: (error) {
        if (!loadCompleter.isCompleted && !loadFinished) {
          loadCompleter.completeError(
            WebPageLoadException(
              'Web resource error: ${error.description} (${error.errorCode})',
            ),
          );
        }
      },
      onNavigationRequest: (request) {
        if (!config.navigationAllowed(request.url)) {
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ),
  );

  await controller.loadRequest(
    uri,
    headers: config.requestHeaders,
  );

  try {
    await loadCompleter.future.timeout(
      Duration(seconds: config.loadTimeoutSeconds),
      onTimeout: () => throw WebPageLoadException(
        'Timed out after ${config.loadTimeoutSeconds}s loading ${config.url}',
      ),
    );
    await _waitForDocumentReady(controller, config.loadTimeoutSeconds);
  } catch (e) {
    // Best-effort cleanup; controller has no explicit dispose API.
    rethrow;
  }

  return _WebViewPreparedSession(controller: controller, config: config);
}

Future<void> _waitForDocumentReady(
  WebViewController controller,
  int timeoutSeconds,
) async {
  const poll = Duration(milliseconds: 100);
  final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
  while (DateTime.now().isBefore(deadline)) {
    final state = await controller.runJavaScriptReturningResult(
      'document.readyState',
    );
    final s = state.toString().replaceAll('"', '');
    if (s == 'complete' || s == 'interactive') {
      return;
    }
    await Future<void>.delayed(poll);
  }
  throw WebPageLoadException('document.readyState did not reach complete');
}

class _WebViewPreparedSession implements WebPagePreparedSession {
  _WebViewPreparedSession({
    required this.controller,
    required this.config,
  });

  final WebViewController controller;
  @override
  final WebPageConfig config;

  @override
  Widget buildView() => WebViewWidget(controller: controller);

  @override
  Future<double> measureScrollableExtent() async {
    final result = await controller.runJavaScriptReturningResult('''
(function() {
  var el = document.documentElement;
  var body = document.body;
  var h = Math.max(
    el ? el.scrollHeight : 0,
    body ? body.scrollHeight : 0,
    window.innerHeight || 0
  );
  return Math.max(0, h - (window.innerHeight || 0));
})()
''');
    if (result is num) {
      return result.toDouble();
    }
    return double.tryParse(result.toString()) ?? 0;
  }

  @override
  Future<void> scrollBy(double delta) async {
    if (delta <= 0) {
      return;
    }
    await controller.runJavaScript('window.scrollBy(0, $delta);');
  }

  @override
  void dispose() {
    // Platform WebView is released when the widget tree drops [WebViewWidget].
  }
}

/// Preload failed; slide still advances with an error panel instead of throwing.
class WebPageFailedSession implements WebPagePreparedSession {
  WebPageFailedSession({required this.config, required this.message});

  @override
  final WebPageConfig config;
  final String message;

  @override
  Widget buildView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      );

  @override
  Future<double> measureScrollableExtent() async => 0;

  @override
  Future<void> scrollBy(double delta) async {}

  @override
  void dispose() {}
}

/// Test-only session that avoids platform WebView channels.
@visibleForTesting
class FakeWebPagePreparedSession implements WebPagePreparedSession {
  FakeWebPagePreparedSession({
    required this.config,
    this.scrollableExtent = 0,
  });

  @override
  final WebPageConfig config;
  final double scrollableExtent;
  var disposed = false;

  @override
  Widget buildView() => const SizedBox(key: Key('web_page_fake_view'));

  @override
  Future<double> measureScrollableExtent() async => scrollableExtent;

  @override
  Future<void> scrollBy(double delta) async {}

  @override
  void dispose() {
    disposed = true;
  }
}
