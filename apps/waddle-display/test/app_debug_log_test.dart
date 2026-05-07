import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/debug/app_debug_log.dart';

void main() {
  test('AppDebugLog methods are safe to call from tests', () {
    AppDebugLog.startup('test startup');
    AppDebugLog.engine('test engine');
    AppDebugLog.curator('test curator');
    AppDebugLog.api('test api');
    AppDebugLog.window('test window');
    AppDebugLog.ticker('test ticker');
    AppDebugLog.screen('test screen');
    AppDebugLog.provider('test provider');
    AppDebugLog.engineFail('ctx', StateError('x'), StackTrace.current);
    AppDebugLog.curatorFail('ctx', StateError('y'), StackTrace.current);
    AppDebugLog.providerFail('ctx', StateError('z'), StackTrace.current);
    expect(AppDebugLog.safeHttpUri(Uri.parse('https://x.example/a?q=secret')),
        'https://x.example/a');
  });
}
