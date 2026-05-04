import 'package:drift/drift.dart';

import '../persistence/database.dart';

/// Idempotent demo rows for stub provider + ticker.
Future<void> ensureInitialSeed(AppDatabase db) async {
  final existing =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('stub')))
          .getSingleOrNull();
  if (existing != null) {
    return;
  }
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'stub',
          providerType: 'stub',
          enabled: const Value(true),
          pollSeconds: const Value(60),
        ),
      );
  await db.into(db.tickerScreens).insert(
        TickerScreensCompanion.insert(
          id: 'welcome',
          sortKey: const Value(0),
          enabled: const Value(true),
          dwellMs: const Value(2500),
          minGapBeforeRepeatMs: const Value(1000),
          bodyText: const Value('Welcome to Waddle View'),
        ),
      );
}
