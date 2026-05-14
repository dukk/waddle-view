import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'debug_console_disk_logger.dart';

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

  /// Slide program from [ScreenRotator] / [ScreenProgramCurator].
  static void screen(String message) => _line('Screen', message);

  /// [IDataProvider] collect, HTTP, and blob downloads (debug only).
  static void provider(String message) => _line('Provider', message);

  static void engineFail(String context, Object error, StackTrace stack) {
    if (!kDebugMode) {
      return;
    }
    DebugConsoleDiskLogger.appendNamedLine(
      'Engine',
      '$context: ${Error.safeToString(error)}',
    );
    DebugConsoleDiskLogger.appendMultiline(stack.toString());
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
    DebugConsoleDiskLogger.appendNamedLine(
      'Curator',
      '$context: ${Error.safeToString(error)}',
    );
    DebugConsoleDiskLogger.appendMultiline(stack.toString());
    developer.log(
      '$context: ${Error.safeToString(error)}',
      name: 'Curator',
      error: error,
      stackTrace: stack,
    );
  }

  static void providerFail(String context, Object error, StackTrace stack) {
    if (!kDebugMode) {
      return;
    }
    DebugConsoleDiskLogger.appendNamedLine(
      'Provider',
      '$context: ${Error.safeToString(error)}',
    );
    DebugConsoleDiskLogger.appendMultiline(stack.toString());
    developer.log(
      '$context: ${Error.safeToString(error)}',
      name: 'Provider',
      error: error,
      stackTrace: stack,
    );
  }

  /// Scheme, host, and path only — omits query (may contain API keys or tokens).
  static String safeHttpUri(Uri uri) {
    if (uri.hasAuthority) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      return '${uri.scheme}://${uri.host}$path';
    }
    return uri.hasEmptyPath ? '(relative)' : uri.path;
  }

  static void _line(String name, String message) {
    if (!kDebugMode) {
      return;
    }
    DebugConsoleDiskLogger.appendNamedLine(name, message);
    developer.log(message, name: name);
  }
}
