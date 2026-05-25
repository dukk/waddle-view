import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/catalog_defaults_reset.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

class _MemBlobStore implements BlobStore {
  final Map<String, List<int>> _data = {};

  @override
  Future<void> delete(BlobRef ref) async => _data.remove(ref.storageKey);

  @override
  Future<BlobRef> putBytes(
    List<int> bytes, {
    required String logicalKey,
  }) async {
    final key = 'stored/$logicalKey';
    _data[key] = List<int>.from(bytes);
    return BlobRef(key);
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async =>
      List<int>.from(_data[ref.storageKey] ?? const []);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

void main() {
  test(
    'resetCatalogToSystemDefaults removes custom catalog and restores factory',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      await ensureInitialSeed(db);

      await db
          .into(db.screens)
          .insert(
            ScreensCompanion.insert(
              id: 'custom_screen',
              label: 'Custom',
              screenType: 'static_text',
            ),
          );
      await db
          .into(db.tickerTapes)
          .insert(
            TickerTapesCompanion.insert(
              id: 'custom_ticker',
              label: 'Custom ticker',
              tickerType: 'static_text',
            ),
          );
      await db
          .into(db.overlays)
          .insert(
            OverlaysCompanion.insert(
              id: 'custom_overlay',
              overlayType: kOverlayTypeShapeRain,
            ),
          );
      await db
          .into(db.curatorConfigurationMembers)
          .insert(
            CuratorConfigurationMembersCompanion.insert(
              configurationId: 'evening',
              entityType: kCuratorMemberEntityScreen,
              entityId: 'custom_screen',
            ),
          );

      final first = await resetCatalogToSystemDefaults(db);
      expect(first.screensRemoved, greaterThan(0));
      expect(first.tickersRemoved, greaterThanOrEqualTo(5));
      expect(first.overlaysRemoved, greaterThan(0));
      expect(first.membersRemoved, greaterThan(0));
      expect(first.screensSeeded, greaterThan(0));
      expect(first.tickersSeeded, 5);
      expect(first.overlaysSeeded, 5);

      final customScreen = await (db.select(
        db.screens,
      )..where((t) => t.id.equals('custom_screen'))).getSingleOrNull();
      expect(customScreen, isNull);

      final customTicker = await (db.select(
        db.tickerTapes,
      )..where((t) => t.id.equals('custom_ticker'))).getSingleOrNull();
      expect(customTicker, isNull);

      final customOverlay = await (db.select(
        db.overlays,
      )..where((t) => t.id.equals('custom_overlay'))).getSingleOrNull();
      expect(customOverlay, isNull);

      final tickers = await (db.select(
        db.tickerTapes,
      )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(tickers.length, 5);
      expect(tickers.map((r) => r.id).toList(), [
        'ticker_time',
        'ticker_weather',
        'ticker_news',
        'ticker_stocks',
        'ticker_custom',
      ]);

      final bootstrapMembers = await (db.select(
        db.curatorConfigurationMembers,
      )..where((t) => t.configurationId.equals('bootstrap'))).get();
      expect(
        bootstrapMembers.any(
          (m) =>
              m.entityType == kCuratorMemberEntityTicker &&
              m.entityId == 'ticker_custom',
        ),
        isFalse,
      );

      final eveningMembers = await (db.select(
        db.curatorConfigurationMembers,
      )..where((t) => t.configurationId.equals('evening'))).get();
      expect(eveningMembers.any((m) => m.entityId == 'custom_screen'), isFalse);

      final second = await resetCatalogToSystemDefaults(db);
      expect(second.screensSeeded, first.screensSeeded);
      expect(second.tickersSeeded, first.tickersSeeded);
      expect(second.overlaysSeeded, first.overlaysSeeded);

      await db.close();
    },
  );

  test(
    'resetCatalogToSystemDefaults reseeds duck overlay blobs without Flutter binding',
    () async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      final blobs = _MemBlobStore();

      final result = await resetCatalogToSystemDefaults(db, blobs: blobs);

      expect(result.overlaysSeeded, 5);
      final blobRows = await db.select(db.blobMetadata).get();
      expect(
        blobRows.map((r) => r.blobKey).toSet(),
        kSeededDuckOverlayBlobKeys.toSet(),
      );

      await db.close();
    },
  );
}
