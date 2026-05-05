import 'package:drift/drift.dart';

import '../debug/app_debug_log.dart';
import '../persistence/database.dart';
import 'data_provider.dart';
import 'data_write_context.dart';

/// Seeds dashboard KV and a tiny blob so collect → SQLite → blob paths work.
class StubDataProvider implements IDataProvider {
  @override
  String get id => 'stub';

  @override
  Future<void> collect(DataWriteContext ctx) async {
    await ctx.db
        .into(ctx.db.dashboardKv)
        .insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'header.title',
            value: 'Waddle View',
          ),
        );
    await ctx.db.into(ctx.db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'ticker.marquee.weather',
            value: '72°F · Sunny',
          ),
        );
    await ctx.db.into(ctx.db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'ticker.marquee.news',
            value: 'Local headlines refresh with each collect',
          ),
        );
    await ctx.db.into(ctx.db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'ticker.marquee.quote',
            value: 'WADDLE +1.2%',
          ),
        );
    final ref = await ctx.blobs.putBytes(
      const <int>[0x57, 0x41], // "WA"
      logicalKey: 'stub/ping',
    );
    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
      BlobMetadataCompanion.insert(
        blobKey: 'stub/ping',
        sha256: ref.storageKey.split('/').last,
        relativePath: ref.storageKey,
        bytes: 2,
        mimeType: const Value('application/octet-stream'),
        capturedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    AppDebugLog.engine('StubDataProvider.collect finished');
  }
}
