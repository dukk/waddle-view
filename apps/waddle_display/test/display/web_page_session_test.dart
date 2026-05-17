import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/bootstrap/webview_platform_bootstrap.dart';
import 'package:waddle_display/display/screens/web_page/web_page_session.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugForceEmbeddedWebViewUnavailable = false;
    resetEmbeddedWebViewBootstrapForTest();
    WebPagePrepareCache.debugLoader = null;
    WebPagePrepareCache.instance.disposeAll();
  });

  test('preload stores failed session when WebView platform is unavailable', () async {
    debugForceEmbeddedWebViewUnavailable = true;

    const spec = ParsedWidgetSpec(
      type: 'web_page',
      slot: 'main',
      config: {'url': 'https://example.com'},
    );

    await WebPagePrepareCache.instance.preload(spec);
    final session = WebPagePrepareCache.instance.takeReady(spec);
    expect(session, isA<WebPageFailedSession>());
    expect(
      (session! as WebPageFailedSession).message,
      embeddedWebViewUnavailableMessage(),
    );
  });

  test('preload maps webview MissingPluginException to rebuild hint', () async {
    WebPagePrepareCache.debugLoader = (_, config) async {
      throw MissingPluginException(
        'No implementation found for method init on channel webview_win_floating',
      );
    };

    const spec = ParsedWidgetSpec(
      type: 'web_page',
      slot: 'main',
      config: {'url': 'https://example.com'},
    );

    await WebPagePrepareCache.instance.preload(spec);
    final session = WebPagePrepareCache.instance.takeReady(spec);
    expect(session, isA<WebPageFailedSession>());
    expect(
      (session! as WebPageFailedSession).message,
      contains('flutter clean'),
    );
  });
}
