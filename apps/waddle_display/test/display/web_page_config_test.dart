import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/web_page/web_page_config.dart';

void main() {
  group('parseWebPageConfig', () {
    test('parses url, headers, scroll, and security', () {
      final cfg = parseWebPageConfig({
        'url': 'https://dashboard.example.com/board',
        'userAgent': 'Waddle/1',
        'requestHeaders': {'X-Token': 'abc'},
        'javascriptEnabled': false,
        'loadTimeoutSeconds': 60,
        'autoScroll': {
          'enabled': true,
          'delayMs': 1000,
          'pixelsPerSecond': 30,
          'trailingHoldMs': 500,
        },
        'security': {
          'restrictNavigation': true,
          'allowedHosts': ['CDN.Example.COM'],
          'blockPopups': true,
          'sandbox': ['allow-same-origin'],
        },
      });

      expect(cfg.url, 'https://dashboard.example.com/board');
      expect(cfg.uri?.host, 'dashboard.example.com');
      expect(cfg.userAgent, 'Waddle/1');
      expect(cfg.requestHeaders, {'X-Token': 'abc'});
      expect(cfg.javascriptEnabled, isFalse);
      expect(cfg.loadTimeoutSeconds, 60);
      expect(cfg.autoScroll.enabled, isTrue);
      expect(cfg.autoScroll.delayMs, 1000);
      expect(cfg.autoScroll.pixelsPerSecond, 30);
      expect(cfg.autoScroll.trailingHoldMs, 500);
      expect(cfg.security.allowedHosts, {'cdn.example.com'});
      expect(cfg.security.sandboxTokens, {'allow-same-origin'});
    });

    test('sandbox without allow-scripts disables javascript', () {
      final cfg = parseWebPageConfig({
        'url': 'https://example.com',
        'javascriptEnabled': true,
        'security': {'sandbox': ['allow-same-origin']},
      });
      expect(cfg.javascriptEnabled, isFalse);
    });

    test('navigationAllowed respects initial host and allowedHosts', () {
      final cfg = parseWebPageConfig({
        'url': 'https://example.com/start',
        'security': {
          'restrictNavigation': true,
          'allowedHosts': ['cdn.example.com'],
        },
      });
      expect(
        cfg.navigationAllowed('https://example.com/other'),
        isTrue,
      );
      expect(
        cfg.navigationAllowed('https://cdn.example.com/asset.js'),
        isTrue,
      );
      expect(
        cfg.navigationAllowed('https://evil.example.net/'),
        isFalse,
      );
      expect(cfg.navigationAllowed('file:///etc/passwd'), isFalse);
    });

    test('webPagePrepareCacheKey is stable for same config', () {
      final cfg = parseWebPageConfig({
        'url': 'https://example.com',
        'requestHeaders': {'a': '1', 'b': '2'},
      });
      final k1 = webPagePrepareCacheKey(choiceKey: 'main_web_page', config: cfg);
      final k2 = webPagePrepareCacheKey(choiceKey: 'main_web_page', config: cfg);
      expect(k1, k2);
    });
  });
}
