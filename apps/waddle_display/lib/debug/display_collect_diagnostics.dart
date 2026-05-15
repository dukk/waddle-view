import 'package:flutter/foundation.dart';

import 'package:waddle_shared/collect/collect_diagnostics.dart';

import 'app_debug_log.dart';
import 'operator_telemetry_hub.dart';

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

/// Forwards to [OperatorTelemetryHub] (works in release).
final class HubCollectDiagnostics implements CollectDiagnostics {
  HubCollectDiagnostics(this._hub);

  final OperatorTelemetryHub _hub;

  @override
  void engine(String message) => _hub.addEngineLine(message);

  @override
  void engineFail(String context, Object error, StackTrace stack) =>
      _hub.addEngineFail(context, error, stack);

  @override
  void provider(String message) => _hub.addProviderLine(message);

  @override
  void providerFail(String context, Object error, StackTrace stack) =>
      _hub.addProviderFail(context, error, stack);
}

final class CompositeCollectDiagnostics implements CollectDiagnostics {
  CompositeCollectDiagnostics(this._parts);

  final List<CollectDiagnostics> _parts;

  @override
  void engine(String message) {
    for (final d in _parts) {
      d.engine(message);
    }
  }

  @override
  void engineFail(String context, Object error, StackTrace stack) {
    for (final d in _parts) {
      d.engineFail(context, error, stack);
    }
  }

  @override
  void provider(String message) {
    for (final d in _parts) {
      d.provider(message);
    }
  }

  @override
  void providerFail(String context, Object error, StackTrace stack) {
    for (final d in _parts) {
      d.providerFail(context, error, stack);
    }
  }
}

/// When [telemetryHub] is set, provider/engine lines are recorded for REST (release too).
/// Debug builds also forward to [AppDebugLog] via [DisplayCollectDiagnostics].
CollectDiagnostics defaultDisplayCollectDiagnostics({
  OperatorTelemetryHub? telemetryHub,
}) {
  final hubDiag =
      telemetryHub != null ? HubCollectDiagnostics(telemetryHub) : null;
  if (kDebugMode) {
    if (hubDiag != null) {
      return CompositeCollectDiagnostics([
        DisplayCollectDiagnostics(),
        hubDiag,
      ]);
    }
    return DisplayCollectDiagnostics();
  }
  if (hubDiag != null) {
    return hubDiag;
  }
  return const ReleaseCollectDiagnostics();
}
