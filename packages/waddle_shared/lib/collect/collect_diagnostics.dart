/// Debug tracing for [DataCollectionEngine] and [IDataProvider] collects.
///
/// Display wiring typically forwards to `AppDebugLog`; headless collectors
/// use [NoOpCollectDiagnostics].
abstract class CollectDiagnostics {
  void engine(String message);

  void engineFail(String context, Object error, StackTrace stack);

  void provider(String message);

  void providerFail(String context, Object error, StackTrace stack);
}

/// Default for tests and non-Flutter engines.
class NoOpCollectDiagnostics implements CollectDiagnostics {
  const NoOpCollectDiagnostics();

  @override
  void engine(String message) {}

  @override
  void engineFail(String context, Object error, StackTrace stack) {}

  @override
  void provider(String message) {}

  @override
  void providerFail(String context, Object error, StackTrace stack) {}
}
