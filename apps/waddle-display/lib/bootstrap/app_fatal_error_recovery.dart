import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

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

void _defaultLogFatal(String channel, Object error, StackTrace? stack) {
  developer.log(
    Error.safeToString(error),
    name: 'Fatal.$channel',
    error: error,
    stackTrace: stack,
  );
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
  stderr.writeln('[Recoverable][Flutter] $message');
}

/// Layout-time [FlutterError] messages (overflow, clipping) that should not
/// tear down the kiosk process; the framework has already reported them via
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
    if (isRecoverableLayoutFlutterError(details)) {
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
