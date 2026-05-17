import '../collect/data_provider.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';

/// Registry of [IDataProvider] instances keyed by integration id.
class DataProviderRegistry {
  DataProviderRegistry({Iterable<IDataProvider> providers = const []})
      : _byId = {for (final p in providers) p.id: p};

  final Map<String, IDataProvider> _byId;

  void register(IDataProvider provider) {
    _byId[provider.id] = provider;
  }

  IDataProvider? lookup(String id) => _byId[id];

  List<IDataProvider> allProviders() =>
      _byId.values.toList(growable: false);

  /// Providers registered and enabled in [integrations], in registration order.
  Future<List<IDataProvider>> providersForEnabledIntegrations(
    AppDatabase db,
  ) async {
    final rows = await db.select(db.integrations).get();
    final enabled = {
      for (final r in rows)
        if (r.enabled) r.id.trim(): true,
    };
    final out = <IDataProvider>[];
    for (final p in _byId.values) {
      if (enabled.containsKey(p.id)) {
        out.add(p);
        continue;
      }
      if (p.id == kPluginHttpCollectorId &&
          rows.any(
            (r) => r.enabled && r.providerType.trim() == kProviderTypePluginHttp,
          )) {
        out.add(p);
      }
    }
    return out;
  }
}

/// [IDataProvider.id] for the generic plugin HTTP collector (not a row id).
const String kPluginHttpCollectorId = 'plugin_http';
