import 'package:drift/drift.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_shared/seed/tables/curator_configurations_seed.dart';
import 'package:waddle_shared/seed/tables/overlay_blobs_seed.dart';

/// Counts from [resetCatalogToSystemDefaults].
class CatalogDefaultsResetResult {
  const CatalogDefaultsResetResult({
    required this.screensRemoved,
    required this.tickersRemoved,
    required this.overlaysRemoved,
    required this.membersRemoved,
    required this.screensSeeded,
    required this.tickersSeeded,
    required this.overlaysSeeded,
  });

  final int screensRemoved;
  final int tickersRemoved;
  final int overlaysRemoved;
  final int membersRemoved;
  final int screensSeeded;
  final int tickersSeeded;
  final int overlaysSeeded;

  Map<String, int> toJson() => {
        'screens_removed': screensRemoved,
        'tickers_removed': tickersRemoved,
        'overlays_removed': overlaysRemoved,
        'members_removed': membersRemoved,
        'screens_seeded': screensSeeded,
        'tickers_seeded': tickersSeeded,
        'overlays_seeded': overlaysSeeded,
      };
}

/// Deletes all screens, ticker tapes, and overlays plus curator membership for
/// those entity types, then re-applies factory catalog rows and program membership.
Future<CatalogDefaultsResetResult> resetCatalogToSystemDefaults(
  AppDatabase db, {
  BlobStore? blobs,
}) async {
  return db.transaction(() async {
    final screensRemoved = await db.delete(db.screens).go();
    final tickersRemoved = await db.delete(db.tickerTapes).go();
    final overlaysRemoved = await db.delete(db.overlays).go();
    final membersRemoved = await (db.delete(db.curatorConfigurationMembers)
          ..where(
            (t) => t.entityType.isIn([
              kCuratorMemberEntityScreen,
              kCuratorMemberEntityTicker,
              kCuratorMemberEntityOverlay,
            ]),
          ))
        .go();

    await ensureDefaultTickerTapesSeed(db);
    await ensureDefaultOverlaysSeed(db);
    await ensureDefaultScreensSeed(db);
    await reseedDefaultCuratorCatalogMembers(db);

    if (blobs != null) {
      await ensureOverlayBlobSeed(db: db, blobs: blobs);
    }

    final screensSeeded = await db.select(db.screens).get();
    final tickersSeeded = await db.select(db.tickerTapes).get();
    final overlaysSeeded = await db.select(db.overlays).get();

    return CatalogDefaultsResetResult(
      screensRemoved: screensRemoved,
      tickersRemoved: tickersRemoved,
      overlaysRemoved: overlaysRemoved,
      membersRemoved: membersRemoved,
      screensSeeded: screensSeeded.length,
      tickersSeeded: tickersSeeded.length,
      overlaysSeeded: overlaysSeeded.length,
    );
  });
}
