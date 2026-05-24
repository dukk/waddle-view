import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/bootstrap/embedded_webview_dispose.dart';

void main() {
  test(
    'isBenignEmbeddedWebViewDisposePlatformException matches dispose race',
    () {
      expect(
        isBenignEmbeddedWebViewDisposePlatformException(
          PlatformException(code: "webview hasn't created"),
        ),
        isTrue,
      );
      expect(
        isBenignEmbeddedWebViewDisposePlatformException(
          PlatformException(code: 'other', message: 'webview hasn broken'),
        ),
        isTrue,
      );
      expect(
        isBenignEmbeddedWebViewDisposePlatformException(
          PlatformException(code: 'other'),
        ),
        isFalse,
      );
    },
  );
}
