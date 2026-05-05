import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug-only tracing (no-op in release). Shows in **Run** / **Debug Console**
/// and **Flutter DevTools** logging.
///
/// **Never** log passwords, API keys, bearer tokens, or `X-Api-Key` values
/// (see repo `AGENTS.md`).
abstract final class AppDebugLog {
  static void startup(String message) => _line('Startup', message);

  static void engine(String message) => _line('Engine', message);

  static void curator(String message) => _line('Curator', message);

  static void api(String message) => _line('API', message);

  static void window(String message) => _line('Window', message);

  static void ticker(String message) => _line('Ticker', message);

  static void engineFail(String context, Object error, StackTrace stack) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      '$context: ${Error.safeToString(error)}',
      name: 'Engine',
      error: error,
      stackTrace: stack,
    );
  }

  static void curatorFail(String context, Object error, StackTrace stack) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      '$context: ${Error.safeToString(error)}',
      name: 'Curator',
      error: error,
      stackTrace: stack,
    );
  }

  static void _line(String name, String message) {
    if (!kDebugMode) {
      return;
    }
    developer.log(message, name: name);
  }
}
