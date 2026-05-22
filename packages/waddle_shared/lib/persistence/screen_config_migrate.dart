import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Rewrites legacy screen [Screens.configJson] shapes (feedId, categoryId, …).
Future<void> migrateScreenConfigJsonV48(AppDatabase db) async {
  if (!await _tableExists(db, 'screens')) {
    return;
  }
  final rows = await db.customSelect(
    'SELECT id, screen_type, config_json FROM screens',
    readsFrom: {db.screens},
  ).get();
  final categories = await db.select(db.contentCategories).get();
  final idToLabel = {for (final c in categories) c.id: c.label};
  final labelToId = <String, String>{};
  for (final c in categories) {
    final label = c.label.trim();
    if (label.isNotEmpty) {
      labelToId.putIfAbsent(label, () => c.id);
    }
  }

  for (final row in rows) {
    final id = row.read<String>('id');
    final screenType = row.read<String>('screen_type');
    final raw = row.read<String>('config_json');
    Map<String, dynamic> config;
    try {
      final decoded = jsonDecode(raw);
      config = decoded is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      continue;
    }
    final next = _migrateOneScreenConfig(
      screenType,
      config,
      idToLabel: idToLabel,
      labelToId: labelToId,
    );
    if (!_mapsEqual(config, next)) {
      await db.customStatement(
        'UPDATE screens SET config_json = ? WHERE id = ?',
        [jsonEncode(next), id],
      );
    }
  }
}

Map<String, dynamic> _migrateOneScreenConfig(
  String screenType,
  Map<String, dynamic> config, {
  required Map<String, String> idToLabel,
  required Map<String, String> labelToId,
}) {
  final out = Map<String, dynamic>.from(config);

  void migrateCategoryIdToName() {
    final cid = out.remove('categoryId');
    if (cid is String && cid.trim().isNotEmpty) {
      final label = idToLabel[cid.trim()] ?? cid.trim();
      out['categoryName'] = label;
    }
    final cids = out.remove('categoryIds');
    if (cids is List && cids.isNotEmpty) {
      final names = <String>[];
      for (final e in cids) {
        if (e is! String || e.trim().isEmpty) continue;
        names.add(idToLabel[e.trim()] ?? e.trim());
      }
      if (names.isNotEmpty) {
        out['categoryNames'] = names;
      }
    }
  }

  switch (screenType) {
    case 'news':
    case 'news_columns':
    case 'news_stack':
    case 'news_grid':
      out.remove('feedId');
      migrateCategoryIdToName();
      if (out.containsKey('imageOnRight')) {
        final onRight = out.remove('imageOnRight');
        if (onRight == true) {
          out['qrMode'] = 'right';
        } else if (onRight == false && out['qrMode'] == null) {
          out['qrMode'] = 'left';
        }
      }
      break;
    case 'calendar_month':
      migrateCategoryIdToName();
      break;
    case 'weather':
      final lid = out.remove('locationId');
      if (lid is String && lid.trim().isNotEmpty) {
        out['locationName'] = lid.trim();
      }
      break;
    case 'stock_quotes':
      final symbolIds = out.remove('symbolIds');
      if (symbolIds is List && symbolIds.isNotEmpty) {
        out['symbols'] = symbolIds
            .whereType<String>()
            .map((s) => s.trim().toUpperCase())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      break;
    case 'joke':
    case 'quote':
    case 'trivia':
    case 'photo':
    case 'photo_collage':
    case 'video':
      migrateCategoryIdToName();
      break;
    default:
      break;
  }
  return out;
}

bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  return jsonEncode(a) == jsonEncode(b);
}

Future<bool> _tableExists(AppDatabase db, String name) async {
  final r = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    variables: [Variable<String>(name)],
  ).getSingleOrNull();
  return r != null;
}
