import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/bootstrap/app_fatal_error_recovery.dart';

FlutterErrorDetails _flutterDetails(Object exception, {String library = 'test'}) {
  return FlutterErrorDetails(
    exception: exception,
    library: library,
  );
}

void main() {
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
}
