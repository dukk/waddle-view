import 'package:flutter/foundation.dart';

import 'package:waddle_shared/collect/collect_diagnostics.dart';

import 'app_debug_log.dart';

/// Bridges [CollectDiagnostics] to [AppDebugLog] for Flutter debug builds.
class DisplayCollectDiagnostics implements CollectDiagnostics {
  @override
  void engine(String message) => AppDebugLog.engine(message);

  @override
  void engineFail(String context, Object error, StackTrace stack) =>
      AppDebugLog.engineFail(context, error, stack);

  @override
  void provider(String message) => AppDebugLog.provider(message);

  @override
  void providerFail(String context, Object error, StackTrace stack) =>
      AppDebugLog.providerFail(context, error, stack);
}

/// Release-safe diagnostics (no Flutter logging dependency for provider package tests).
class ReleaseCollectDiagnostics implements CollectDiagnostics {
  const ReleaseCollectDiagnostics();

  @override
  void engine(String message) {}

  @override
  void engineFail(String context, Object error, StackTrace stack) {}

  @override
  void provider(String message) {}

  @override
  void providerFail(String context, Object error, StackTrace stack) {}
}

CollectDiagnostics defaultDisplayCollectDiagnostics() =>
    kDebugMode ? DisplayCollectDiagnostics() : const ReleaseCollectDiagnostics();
