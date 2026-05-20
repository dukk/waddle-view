/// Debug tracing for [DataCollectionEngine] and [IDataProvider] collects.
///
/// Display wiring typically forwards to `AppDebugLog`; headless collectors
/// use [NoOpCollectDiagnostics].
abstract class CollectDiagnostics {
  void engine(String message, {String? integrationType});

  void engineFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  });

  void provider(String message, {String? integrationType});

  void providerFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  });
}

/// Default for tests and non-Flutter engines.
class NoOpCollectDiagnostics implements CollectDiagnostics {
  const NoOpCollectDiagnostics();

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
