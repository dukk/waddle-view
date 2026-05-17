import '../collect/data_provider.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';

/// Registry of [IDataProvider] instances keyed by [Integrations.integrationType].
class DataProviderRegistry {
  DataProviderRegistry({Iterable<IDataProvider> providers = const []})
      : _byType = {for (final p in providers) p.id: p};

  final Map<String, IDataProvider> _byType;

  void register(IDataProvider provider) {
    _byType[provider.id] = provider;
  }

  IDataProvider? lookupByType(String integrationType) =>
      _byType[integrationType];

  List<IDataProvider> allProviders() =>
      _byType.values.toList(growable: false);

  /// Providers with at least one enabled integration row, in registration order.
  Future<List<IDataProvider>> providersForEnabledIntegrations(
    AppDatabase db,
  ) async {
    final rows = await db.select(db.integrations).get();
    final enabledTypes = <String>{
      for (final r in rows)
        if (r.enabled) r.integrationType.trim(),
    };
    final out = <IDataProvider>[];
    for (final p in _byType.values) {
      if (enabledTypes.contains(p.id)) {
        out.add(p);
        continue;
      }
      if (p.id == kPluginHttpCollectorId &&
          rows.any(
            (r) =>
                r.enabled &&
                r.integrationType.trim() == kProviderTypePluginHttp,
          )) {
        out.add(p);
      }
    }
    return out;
  }
}

/// [IDataProvider.id] for the generic plugin HTTP collector (not a row id).
const String kPluginHttpCollectorId = 'plugin_http';
