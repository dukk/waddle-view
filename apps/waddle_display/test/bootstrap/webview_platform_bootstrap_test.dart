import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/bootstrap/webview_platform_bootstrap.dart';

void main() {
  tearDown(resetEmbeddedWebViewBootstrapForTest);

  test('debugForceEmbeddedWebViewUnavailable hides embedded web view', () {
    debugForceEmbeddedWebViewUnavailable = true;
    expect(isEmbeddedWebViewAvailable, isFalse);
  });
}
