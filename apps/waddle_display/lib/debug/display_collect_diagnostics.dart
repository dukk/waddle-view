import 'package:flutter/foundation.dart';

import 'package:waddle_shared/collect/collect_diagnostics.dart';

import 'app_debug_log.dart';
import 'operator_telemetry_hub.dart';

/// Bridges [CollectDiagnostics] to [AppDebugLog] for Flutter debug builds.
class DisplayCollectDiagnostics implements CollectDiagnostics {
  @override
  void engine(String message, {String? integrationType}) =>
      AppDebugLog.engine(message);

  @override
  void engineFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) =>
      AppDebugLog.engineFail(context, error, stack);

  @override
  void provider(String message, {String? integrationType}) =>
      AppDebugLog.provider(message);

  @override
  void providerFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) =>
      AppDebugLog.providerFail(context, error, stack);
}

/// Release-safe diagnostics (no Flutter logging dependency for provider package tests).
class ReleaseCollectDiagnostics implements CollectDiagnostics {
  const ReleaseCollectDiagnostics();

  @override
  void engine(String message, {String? integrationType}) {}

  @override
  void engineFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) {}

  @override
  void provider(String message, {String? integrationType}) {}

  @override
  void providerFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) {}
}

/// Forwards to [OperatorTelemetryHub] (works in release).
final class HubCollectDiagnostics implements CollectDiagnostics {
  HubCollectDiagnostics(this._hub);

  final OperatorTelemetryHub _hub;

  @override
  void engine(String message, {String? integrationType}) =>
      _hub.addEngineLine(message, integrationType: integrationType);

  @override
  void engineFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) =>
      _hub.addEngineFail(context, error, stack, integrationType: integrationType);

  @override
  void provider(String message, {String? integrationType}) =>
      _hub.addIntegrationLine(message, integrationType: integrationType);

  @override
  void providerFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) =>
      _hub.addIntegrationFail(
        context,
        error,
        stack,
        integrationType: integrationType,
      );
}

final class CompositeCollectDiagnostics implements CollectDiagnostics {
  CompositeCollectDiagnostics(this._parts);

  final List<CollectDiagnostics> _parts;

  @override
  void engine(String message, {String? integrationType}) {
    for (final d in _parts) {
      d.engine(message, integrationType: integrationType);
    }
  }

  @override
  void engineFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) {
    for (final d in _parts) {
      d.engineFail(context, error, stack, integrationType: integrationType);
    }
  }

  @override
  void provider(String message, {String? integrationType}) {
    for (final d in _parts) {
      d.provider(message, integrationType: integrationType);
    }
  }

  @override
  void providerFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) {
    for (final d in _parts) {
      d.providerFail(context, error, stack, integrationType: integrationType);
    }
  }
}

/// When [telemetryHub] is set, integration/engine lines are recorded for REST (release too).
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
