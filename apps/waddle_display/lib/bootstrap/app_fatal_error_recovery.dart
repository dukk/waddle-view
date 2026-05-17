import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../debug/debug_console_disk_logger.dart';

/// Prevents nested fatal handling (e.g. errors during logging or restart).
final class FatalHandlingGate {
  bool _busy = false;

  bool tryEnter() {
    if (_busy) {
      return false;
    }
    _busy = true;
    return true;
  }

  @visibleForTesting
  void resetForTest() {
    _busy = false;
  }
}

final FatalHandlingGate _fatalGate = FatalHandlingGate();

@visibleForTesting
void resetFatalHandlingGateForTest() {
  _fatalGate.resetForTest();
}

@visibleForTesting
void invokeDefaultLogFatalForTest(
  String channel,
  Object error,
  StackTrace? stack,
) {
  _defaultLogFatal(channel, error, stack);
}

@visibleForTesting
void invokeDefaultRecoverableFlutterLayoutForTest(
  FlutterErrorDetails details,
) {
  _defaultLogRecoverableFlutterLayout(details);
}

void _defaultLogFatal(String channel, Object error, StackTrace? stack) {
  developer.log(
    Error.safeToString(error),
    name: 'Fatal.$channel',
    error: error,
    stackTrace: stack,
  );
  if (kDebugMode) {
    DebugConsoleDiskLogger.appendNamedLine(
      'Fatal.$channel',
      Error.safeToString(error),
    );
    if (stack != null) {
      DebugConsoleDiskLogger.appendMultiline(stack.toString());
    }
  }
  stderr.writeln('[Fatal][$channel] ${Error.safeToString(error)}');
  if (stack != null) {
    stderr.writeln(stack.toString());
  }
}

void _defaultLogRecoverableFlutterLayout(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  developer.log(
    message,
    name: 'Flutter.recoverable',
    error: details.exception,
    stackTrace: details.stack,
  );
  if (kDebugMode) {
    DebugConsoleDiskLogger.appendNamedLine('Flutter.recoverable', message);
    final st = details.stack;
    if (st != null) {
      DebugConsoleDiskLogger.appendMultiline(st.toString());
    }
  }
  stderr.writeln('[Recoverable][Flutter] $message');
}

/// Layout-time [FlutterError] messages (overflow, clipping) that should not
/// tear down the display process; the framework has already reported them via
/// [FlutterError.presentError].
@visibleForTesting
bool isRecoverableLayoutFlutterError(FlutterErrorDetails details) {
  final ex = details.exception;
  if (ex is! FlutterError) return false;
  final m = ex.message;
  return m.contains('RenderFlex overflowed') ||
      m.contains('RenderParagraph overflowed') ||
      (m.contains('overflowed by') && m.contains('pixels'));
}

/// `HardwareKeyboard._assertEventIsRegular` fires when the OS delivers a
/// `KeyUpEvent` for a key Flutter never observed pressed (focus-loss /
/// Alt-Tab on Windows, modifier held during launch, IME, remote-desktop).
/// Restarting the display on every such event is hostile to UX; the framework
/// recovers cleanly on the next event, so we treat it as recoverable.
@visibleForTesting
bool isRecoverableHardwareKeyboardError(FlutterErrorDetails details) {
  if (details.exception is! AssertionError) return false;
  final stack = details.stack?.toString();
  if (stack == null) return false;
  return stack.contains(
    'package:flutter/src/services/hardware_keyboard.dart',
  );
}

/// media_kit texture resize / platform teardown races during slide transitions
/// should not restart the display; the slide widget retries or shows an error.
@visibleForTesting
bool isRecoverableMediaKitFlutterError(FlutterErrorDetails details) {
  final stack = details.stack?.toString();
  if (stack == null) {
    return false;
  }
  if (!stack.contains('package:media_kit_video/') &&
      !stack.contains('package:media_kit/')) {
    return false;
  }
  final ex = details.exception;
  return ex is StateError || ex is FlutterError;
}

Future<void> _defaultRestartProcess() async {
  if (kIsWeb) {
    stderr.writeln('[Fatal] restart skipped on web');
    exit(1);
  }
  try {
    await Process.start(
      Platform.resolvedExecutable,
      Platform.executableArguments,
      mode: ProcessStartMode.detached,
    );
    exit(0);
  } catch (e, st) {
    _defaultLogFatal('Restart', e, st);
    exit(1);
  }
}

/// Shared handler for framework, platform, and zone failures.
@visibleForTesting
void reactToFatalAppError(
  String channel,
  Object error,
  StackTrace? stack,
  FatalHandlingGate gate,
  void Function(String channel, Object error, StackTrace? stack) logFatal,
  Future<void> Function() restartProcess,
) {
  if (!gate.tryEnter()) {
    return;
  }
  logFatal(channel, error, stack);
  unawaited(restartProcess());
}

/// Registers [FlutterError.onError], [PlatformDispatcher.onError], and should
/// be used together with [runZonedGuarded] in [main] for zone errors.
void installGlobalFatalErrorHandlers({
  void Function(String channel, Object error, StackTrace? stack)? logFatal,
  Future<void> Function()? restartProcess,
  void Function(FlutterErrorDetails details)? logRecoverableLayoutFlutter,
}) {
  final log = logFatal ?? _defaultLogFatal;
  final restart = restartProcess ?? _defaultRestartProcess;
  final logRecoverable =
      logRecoverableLayoutFlutter ?? _defaultLogRecoverableFlutterLayout;

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (isRecoverableLayoutFlutterError(details) ||
        isRecoverableHardwareKeyboardError(details) ||
        isRecoverableMediaKitFlutterError(details)) {
      logRecoverable(details);
      return;
    }
    reactToFatalAppError(
      'Flutter',
      details.exception,
      details.stack,
      _fatalGate,
      log,
      restart,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final details = FlutterErrorDetails(exception: error, stack: stack);
    if (isRecoverableHardwareKeyboardError(details) ||
        isRecoverableMediaKitFlutterError(details)) {
      logRecoverable(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: isRecoverableMediaKitFlutterError(details)
              ? 'media_kit'
              : 'services',
        ),
      );
      return true;
    }
    reactToFatalAppError('Platform', error, stack, _fatalGate, log, restart);
    return true;
  };
}

/// For use as the second argument to [runZonedGuarded] alongside
/// [installGlobalFatalErrorHandlers].
void onZoneFatalError(
  Object error,
  StackTrace stack, {
  void Function(String channel, Object error, StackTrace? stack)? logFatal,
  Future<void> Function()? restartProcess,
}) {
  final log = logFatal ?? _defaultLogFatal;
  final restart = restartProcess ?? _defaultRestartProcess;
  reactToFatalAppError('Zone', error, stack, _fatalGate, log, restart);
}
