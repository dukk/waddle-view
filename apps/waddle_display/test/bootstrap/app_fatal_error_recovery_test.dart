import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_display/bootstrap/app_fatal_error_recovery.dart';
import 'package:waddle_display/debug/debug_console_disk_logger.dart';

FlutterErrorDetails _flutterDetails(
  Object exception, {
  String library = 'test',
  StackTrace? stack,
}) {
  return FlutterErrorDetails(
    exception: exception,
    library: library,
    stack: stack,
  );
}

StackTrace _hardwareKeyboardStack() {
  return StackTrace.fromString(
    '#0      _AssertionError._doThrowNew (dart:core-patch/errors_patch.dart:67:4)\n'
    '#1      _AssertionError._throwNew (dart:core-patch/errors_patch.dart:49:5)\n'
    '#2      HardwareKeyboard._assertEventIsRegular.<anonymous closure> '
    '(package:flutter/src/services/hardware_keyboard.dart:516:11)\n'
    '#3      HardwareKeyboard._assertEventIsRegular '
    '(package:flutter/src/services/hardware_keyboard.dart:536:6)\n'
    '#4      HardwareKeyboard.handleKeyEvent '
    '(package:flutter/src/services/hardware_keyboard.dart:660:5)\n',
  );
}

void main() {
  tearDown(() async {
    DebugConsoleDiskLogger.setSupportDirectoryOverrideForTest(null);
    await DebugConsoleDiskLogger.closeForTest();
  });

  tearDown(resetFatalHandlingGateForTest);

  test('reactToFatalAppError logs and restarts only on first call', () async {
    final gate = FatalHandlingGate();
    var logCount = 0;
    String? lastChannel;
    Object? lastError;
    var restartCount = 0;

    void log(String channel, Object error, StackTrace? stack) {
      logCount++;
      lastChannel = channel;
      lastError = error;
    }

    Future<void> restart() async {
      restartCount++;
    }

    reactToFatalAppError('Flutter', StateError('x'), StackTrace.current, gate,
        log, restart);
    reactToFatalAppError('Zone', StateError('y'), null, gate, log, restart);

    expect(logCount, 1);
    expect(lastChannel, 'Flutter');
    expect(lastError, isA<StateError>());
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 1);
  });

  test('FatalHandlingGate allows a new sequence after resetForTest', () {
    final gate = FatalHandlingGate();
    expect(gate.tryEnter(), isTrue);
    expect(gate.tryEnter(), isFalse);
    gate.resetForTest();
    expect(gate.tryEnter(), isTrue);
  });

  test('onZoneFatalError invokes injectable log and restart once', () async {
    final logs = <String>[];
    var restartCount = 0;
    onZoneFatalError(
      Exception('zone'),
      StackTrace.current,
      logFatal: (channel, error, stack) =>
          logs.add('$channel:${error.runtimeType}'),
      restartProcess: () async {
        restartCount++;
      },
    );
    onZoneFatalError(
      Exception('ignored'),
      StackTrace.current,
      logFatal: (channel, error, stack) => logs.add('x'),
      restartProcess: () async {},
    );
    expect(logs.single, startsWith('Zone:'));
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 1);
  });

  test('onZoneFatalError invokes restartProcess for a zone error', () async {
    var restartCount = 0;
    onZoneFatalError(
      FormatException('bad'),
      StackTrace.current,
      logFatal: (_, _, _) {},
      restartProcess: () async {
        restartCount++;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 1);
  });

  test('isRecoverableLayoutFlutterError matches common overflow assertions', () {
    expect(
      isRecoverableLayoutFlutterError(
        _flutterDetails(
          FlutterError('A RenderFlex overflowed by 131 pixels on the bottom.'),
        ),
      ),
      isTrue,
    );
    expect(
      isRecoverableLayoutFlutterError(
        _flutterDetails(
          FlutterError('A RenderParagraph overflowed by 4.0 pixels on the right.'),
        ),
      ),
      isTrue,
    );
    expect(
      isRecoverableLayoutFlutterError(
        _flutterDetails(Exception('A RenderFlex overflowed')),
      ),
      isFalse,
    );
    expect(
      isRecoverableLayoutFlutterError(
        _flutterDetails(FlutterError('Some other framework failure')),
      ),
      isFalse,
    );
    expect(
      isRecoverableLayoutFlutterError(
        _flutterDetails(
          FlutterError('A ClipRect overflowed by 3.0 pixels on the bottom.'),
        ),
      ),
      isTrue,
    );
  });

  test(
    'installGlobalFatalErrorHandlers uses default recoverable logger on overflow',
    () async {
      final previousFlutter = FlutterError.onError;
      final previousPlatform = PlatformDispatcher.instance.onError;
      final previousPresent = FlutterError.presentError;
      addTearDown(() async {
        FlutterError.onError = previousFlutter;
        PlatformDispatcher.instance.onError = previousPlatform;
        FlutterError.presentError = previousPresent;
        resetFatalHandlingGateForTest();
        await DebugConsoleDiskLogger.closeForTest();
      });
      FlutterError.presentError = (_) {};
      installGlobalFatalErrorHandlers(
        logFatal: (_, _, _) {},
        restartProcess: () async {},
      );
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: FlutterError('A RenderFlex overflowed by 2 pixels.'),
          stack: StackTrace.current,
          library: 'rendering',
        ),
      );
      await DebugConsoleDiskLogger.closeForTest();
    },
  );

  StackTrace _mediaKitVideoStack() {
    return StackTrace.fromString(
      '#0      NativeVideoController.resize '
      '(package:media_kit_video/src/video_controller/native_video_controller/real.dart:10:5)\n'
      '#1      VideoState.build '
      '(package:media_kit_video/src/video/video_texture.dart:20:5)\n',
    );
  }

  test('isRecoverableMediaKitFlutterError matches media_kit_video stacks', () {
    expect(
      isRecoverableMediaKitFlutterError(
        _flutterDetails(
          StateError('texture unavailable'),
          stack: _mediaKitVideoStack(),
        ),
      ),
      isTrue,
    );
    expect(
      isRecoverableMediaKitFlutterError(
        _flutterDetails(
          FlutterError('VideoOutput resize failed'),
          stack: _mediaKitVideoStack(),
        ),
      ),
      isTrue,
    );
    expect(
      isRecoverableMediaKitFlutterError(
        _flutterDetails(
          StateError('texture unavailable'),
          stack: StackTrace.current,
        ),
      ),
      isFalse,
    );
    expect(
      isRecoverableMediaKitFlutterError(
        _flutterDetails(
          Exception('not a framework error'),
          stack: _mediaKitVideoStack(),
        ),
      ),
      isFalse,
    );
  });

  test('isRecoverableHardwareKeyboardError matches HardwareKeyboard assertions',
      () {
    expect(
      isRecoverableHardwareKeyboardError(
        _flutterDetails(
          AssertionError('A KeyUpEvent is dispatched, but the state shows that '
              'the physical key is not pressed.'),
          stack: _hardwareKeyboardStack(),
        ),
      ),
      isTrue,
    );
    expect(
      isRecoverableHardwareKeyboardError(
        _flutterDetails(
          Exception('not an assertion'),
          stack: _hardwareKeyboardStack(),
        ),
      ),
      isFalse,
    );
    expect(
      isRecoverableHardwareKeyboardError(
        _flutterDetails(
          AssertionError('unrelated assertion'),
          stack: StackTrace.fromString('#0 someOther (package:foo/bar.dart)'),
        ),
      ),
      isFalse,
    );
    expect(
      isRecoverableHardwareKeyboardError(
        _flutterDetails(AssertionError('no stack')),
      ),
      isFalse,
    );
  });

  test('installGlobalFatalErrorHandlers does not restart on hardware keyboard '
      'assertion', () async {
    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    final previousPresent = FlutterError.presentError;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
      FlutterError.presentError = previousPresent;
      resetFatalHandlingGateForTest();
    });
    FlutterError.presentError = (_) {};
    final channels = <String>[];
    var restartCount = 0;
    var recoverableCount = 0;
    installGlobalFatalErrorHandlers(
      logFatal: (channel, error, stack) => channels.add(channel),
      restartProcess: () async {
        restartCount++;
      },
      logRecoverableLayoutFlutter: (_) {
        recoverableCount++;
      },
    );
    FlutterError.onError!(
      _flutterDetails(
        AssertionError('A KeyUpEvent is dispatched, but the state shows that '
            'the physical key is not pressed.'),
        stack: _hardwareKeyboardStack(),
      ),
    );
    expect(channels, isEmpty);
    expect(recoverableCount, 1);
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 0);
  });

  test('installGlobalFatalErrorHandlers does not restart on layout overflow',
      () async {
    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    final previousPresent = FlutterError.presentError;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
      FlutterError.presentError = previousPresent;
      resetFatalHandlingGateForTest();
    });
    FlutterError.presentError = (_) {};
    final channels = <String>[];
    var restartCount = 0;
    var recoverableCount = 0;
    installGlobalFatalErrorHandlers(
      logFatal: (channel, error, stack) => channels.add(channel),
      restartProcess: () async {
        restartCount++;
      },
      logRecoverableLayoutFlutter: (_) {
        recoverableCount++;
      },
    );
    FlutterError.onError!(
      _flutterDetails(
        FlutterError('A RenderFlex overflowed by 1 pixel on the bottom.'),
      ),
    );
    expect(channels, isEmpty);
    expect(recoverableCount, 1);
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 0);
  });

  test('installGlobalFatalErrorHandlers invokes injectable log on FlutterError',
      () async {
    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    final previousPresent = FlutterError.presentError;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
      FlutterError.presentError = previousPresent;
      resetFatalHandlingGateForTest();
    });
    FlutterError.presentError = (_) {};
    final channels = <String>[];
    var restartCount = 0;
    installGlobalFatalErrorHandlers(
      logFatal: (channel, error, stack) => channels.add(channel),
      restartProcess: () async {
        restartCount++;
      },
    );
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: Exception('widget'),
        library: 'test',
      ),
    );
    expect(channels, ['Flutter']);
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 1);
  });

  test('installGlobalFatalErrorHandlers does not restart on hardware keyboard '
      'assertion via platform onError', () async {
    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
      resetFatalHandlingGateForTest();
    });
    final channels = <String>[];
    var restartCount = 0;
    var recoverableCount = 0;
    installGlobalFatalErrorHandlers(
      logFatal: (channel, error, stack) => channels.add(channel),
      restartProcess: () async {
        restartCount++;
      },
      logRecoverableLayoutFlutter: (_) {
        recoverableCount++;
      },
    );
    final handled = PlatformDispatcher.instance.onError!(
      AssertionError('A KeyUpEvent is dispatched, but the state shows that '
          'the physical key is not pressed.'),
      _hardwareKeyboardStack(),
    );
    expect(handled, isTrue);
    expect(channels, isEmpty);
    expect(recoverableCount, 1);
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 0);
  });

  test('installGlobalFatalErrorHandlers wires platform onError', () async {
    final previousFlutter = FlutterError.onError;
    final previousPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      PlatformDispatcher.instance.onError = previousPlatform;
      resetFatalHandlingGateForTest();
    });
    final channels = <String>[];
    var restartCount = 0;
    installGlobalFatalErrorHandlers(
      logFatal: (channel, error, stack) => channels.add(channel),
      restartProcess: () async {
        restartCount++;
      },
    );
    PlatformDispatcher.instance.onError!(
      Exception('platform'),
      StackTrace.current,
    );
    expect(channels, ['Platform']);
    await Future<void>.delayed(Duration.zero);
    expect(restartCount, 1);
  });

  test('invokeDefaultLogFatalForTest tees to debug disk logger', () async {
    if (!kDebugMode) {
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('fatal_disk_log_');
    addTearDown(() async {
      await DebugConsoleDiskLogger.closeForTest();
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });
    await DebugConsoleDiskLogger.installForTest(tmp);
    invokeDefaultLogFatalForTest('TestCh', StateError('e'), StackTrace.current);
    await DebugConsoleDiskLogger.closeForTest();

    final logsDir = Directory(p.join(tmp.path, 'debug_console_logs'));
    final file = logsDir.listSync().whereType<File>().single;
    final text = await file.readAsString();
    expect(text, contains('[Fatal.TestCh]'));
    expect(text, contains("Instance of 'StateError'"));
  });

  test('invokeDefaultLogFatalForTest disk branch without stack', () async {
    if (!kDebugMode) {
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('fatal_disk_log_');
    addTearDown(() async {
      await DebugConsoleDiskLogger.closeForTest();
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });
    await DebugConsoleDiskLogger.installForTest(tmp);
    invokeDefaultLogFatalForTest('NoStack', StateError('e'), null);
    await DebugConsoleDiskLogger.closeForTest();

    final logsDir = Directory(p.join(tmp.path, 'debug_console_logs'));
    final file = logsDir.listSync().whereType<File>().single;
    final text = await file.readAsString();
    expect(text, contains('[Fatal.NoStack]'));
    expect(text, isNot(contains('#0')));
  });

  test('invokeDefaultRecoverableFlutterLayoutForTest tees to disk', () async {
    if (!kDebugMode) {
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('recv_disk_log_');
    addTearDown(() async {
      await DebugConsoleDiskLogger.closeForTest();
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });
    await DebugConsoleDiskLogger.installForTest(tmp);
    invokeDefaultRecoverableFlutterLayoutForTest(
      FlutterErrorDetails(
        exception: FlutterError('overflow'),
        library: 'test',
        stack: StackTrace.fromString('#0 fake'),
      ),
    );
    await DebugConsoleDiskLogger.closeForTest();

    final logsDir = Directory(p.join(tmp.path, 'debug_console_logs'));
    final file = logsDir.listSync().whereType<File>().single;
    final text = await file.readAsString();
    expect(text, contains('[Flutter.recoverable]'));
    expect(text, contains('#0 fake'));
  });

  test('invokeDefaultRecoverableFlutterLayoutForTest without stack', () async {
    if (!kDebugMode) {
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('recv_disk_log_');
    addTearDown(() async {
      await DebugConsoleDiskLogger.closeForTest();
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });
    await DebugConsoleDiskLogger.installForTest(tmp);
    invokeDefaultRecoverableFlutterLayoutForTest(
      FlutterErrorDetails(
        exception: FlutterError('overflow'),
        library: 'test',
      ),
    );
    await DebugConsoleDiskLogger.closeForTest();

    final logsDir = Directory(p.join(tmp.path, 'debug_console_logs'));
    final file = logsDir.listSync().whereType<File>().single;
    final text = await file.readAsString();
    expect(text, contains('[Flutter.recoverable]'));
  });
}
