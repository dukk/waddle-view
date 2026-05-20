import 'collect_diagnostics.dart';

/// Forwards to [base], defaulting [integrationType] on provider lines.
final class IntegrationTaggedCollectDiagnostics implements CollectDiagnostics {
  IntegrationTaggedCollectDiagnostics(
    this._base, {
    required this.integrationType,
  });

  final CollectDiagnostics _base;
  final String integrationType;

  @override
  void engine(String message, {String? integrationType}) =>
      _base.engine(message, integrationType: integrationType);

  @override
  void engineFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) =>
      _base.engineFail(context, error, stack, integrationType: integrationType);

  @override
  void provider(String message, {String? integrationType}) =>
      _base.provider(
        message,
        integrationType: integrationType ?? this.integrationType,
      );

  @override
  void providerFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) =>
      _base.providerFail(
        context,
        error,
        stack,
        integrationType: integrationType ?? this.integrationType,
      );
}
