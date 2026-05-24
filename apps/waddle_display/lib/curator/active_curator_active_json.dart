import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';

/// JSON for [GET /v1/curator/active] program toggles and merged catalog membership.
Future<Map<String, Object?>> activeCuratorExtendedJson({
  required AppDatabase db,
  required ResolvedCuratorSelection selection,
}) async {
  final primary = selection.primary.configuration;
  return {
    'program_controls': {
      'screens_enabled': primary.screensEnabled,
      'ticker_enabled': primary.tickerEnabled,
    },
    'effective_members': {
      'screens': await _effectiveMembersJson(
        db,
        selection.effectiveScreenMemberIds,
        entityType: _ActiveMemberEntity.screens,
      ),
      'tickers': await _effectiveMembersJson(
        db,
        selection.effectiveTickerMemberIds,
        entityType: _ActiveMemberEntity.tickers,
      ),
      'overlays': await _effectiveMembersJson(
        db,
        selection.effectiveOverlayMemberIds,
        entityType: _ActiveMemberEntity.overlays,
      ),
    },
  };
}

enum _ActiveMemberEntity { screens, tickers, overlays }

Future<List<Map<String, String>>> _effectiveMembersJson(
  AppDatabase db,
  Set<String> ids, {
  required _ActiveMemberEntity entityType,
}) async {
  if (ids.isEmpty) {
    return const [];
  }
  final labels = <String, String>{};
  switch (entityType) {
    case _ActiveMemberEntity.screens:
      final rows = await (db.select(
        db.screens,
      )..where((t) => t.id.isIn(ids.toList()))).get();
      for (final row in rows) {
        labels[row.id] = row.label.trim().isEmpty ? row.id : row.label;
      }
    case _ActiveMemberEntity.tickers:
      final rows = await (db.select(
        db.tickerTapes,
      )..where((t) => t.id.isIn(ids.toList()))).get();
      for (final row in rows) {
        labels[row.id] = row.label.trim().isEmpty ? row.id : row.label;
      }
    case _ActiveMemberEntity.overlays:
      await ensureOverlaysTableExists(db);
      final rows = await fetchDisplayOverlays(db);
      for (final row in rows) {
        if (ids.contains(row.id)) {
          labels[row.id] = row.label.trim().isEmpty ? row.id : row.label;
        }
      }
  }
  final out = <Map<String, String>>[];
  for (final id in ids) {
    out.add({'id': id, 'label': labels[id] ?? id});
  }
  out.sort((a, b) {
    final byLabel = a['label']!.compareTo(b['label']!);
    if (byLabel != 0) {
      return byLabel;
    }
    return a['id']!.compareTo(b['id']!);
  });
  return out;
}
