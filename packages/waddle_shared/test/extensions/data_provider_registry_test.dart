import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/extensions/data_provider_registry.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/tables/integration_types_seed.dart';

import '../helpers/memory_database.dart';

class _StubProvider implements IDataProvider {
  _StubProvider(this.id);

  @override
  final String id;

  @override
  Future<void> collect(DataWriteContext ctx) async {}
}

void main() {
  test('providersForEnabledIntegrations includes matching types', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await ensureIntegrationTypes(db);

    final registry = DataProviderRegistry(
      providers: [
        _StubProvider('photo_pexels'),
        _StubProvider(kPluginHttpCollectorId),
      ],
    );

    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'pexels1',
            integrationType: 'photo_pexels',
            enabled: const Value(true),
          ),
        );

    final enabled = await registry.providersForEnabledIntegrations(db);
    expect(enabled.map((p) => p.id), ['photo_pexels']);
  });

  test(
    'providersForEnabledIntegrations includes plugin_http when plugin_http row enabled',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await warmDatabase(db);
      await ensureIntegrationTypes(db);

      final registry = DataProviderRegistry(
        providers: [_StubProvider(kPluginHttpCollectorId)],
      );

      await db.into(db.integrations).insert(
            IntegrationsCompanion.insert(
              id: 'plugin_row',
              integrationType: kProviderTypePluginHttp,
              enabled: const Value(true),
            ),
          );

      final enabled = await registry.providersForEnabledIntegrations(db);
      expect(enabled.map((p) => p.id), [kPluginHttpCollectorId]);
    },
  );
}
