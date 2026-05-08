import '../../../alerts/alert_severity_icons_kv.dart';
import '../../../config/google_kv.dart';
import '../../../config/microsoft_graph_kv.dart';
import '../../../persistence/database.dart';
import '../../../persistence/tables.dart';
import '../../../theme/display_text_scale_kv.dart';
import '../../../theme/display_theme_kv.dart';

/// Demo ticker marquee lines inserted once alongside the stub provider row.
Future<void> ensureStubTickerMarqueeKvs(AppDatabase db) async {
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: 'ticker.marquee.news',
          value: 'Welcome to Waddle View',
        ),
      );
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: 'ticker.marquee.weather',
          value: '— °F · demo',
        ),
      );
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: 'ticker.marquee.quote',
          value: 'Market data updates after each collect',
        ),
      );
}

Future<void> ensureDisplayThemeKv(AppDatabase db) async {
  final row = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kDisplayThemeIdKvKey)))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.configKeyValues).insert(
        ConfigKeyValuesCompanion.insert(
          key: kDisplayThemeIdKvKey,
          value: kDefaultDisplayThemeId,
        ),
      );
}

Future<void> ensureDisplayTextScaleKvs(AppDatabase db) async {
  Future<void> ensureKey(String key, String value) async {
    final row = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (row != null) {
      return;
    }
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(key: key, value: value),
        );
  }

  await ensureKey(kDisplayTextScaleScreenKvKey, kDisplayTextScaleNormal);
  await ensureKey(kDisplayTextScaleTickerKvKey, kDisplayTextScaleNormal);
}

Future<void> ensureAlertSeverityIconsKv(AppDatabase db) async {
  final row = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kAlertSeverityIconsKvKey)))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.configKeyValues).insert(
        ConfigKeyValuesCompanion.insert(
          key: kAlertSeverityIconsKvKey,
          value: kDefaultAlertSeverityIconsJson,
        ),
      );
}

Future<void> ensureCuratorSettingsKvs(AppDatabase db) async {
  Future<void> ensureKey(String key, String value) async {
    final row = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (row != null) {
      return;
    }
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(key: key, value: value),
        );
  }

  await ensureKey(kCuratorProgramDurationSecondsKvKey, '180');
  await ensureKey(kCuratorHistoryDepthKvKey, '5');
  await ensureKey(kRequireNewsPhotoForScreensKvKey, 'true');
  await (db.delete(
    db.configKeyValues,
  )..where((t) => t.key.equals('curator.news.require_photo_for_curation'))).go();
}

Future<void> ensureMicrosoftGraphClientIdKv(AppDatabase db) async {
  final row = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kMicrosoftGraphClientIdKvKey)))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.configKeyValues).insert(
        ConfigKeyValuesCompanion.insert(
          key: kMicrosoftGraphClientIdKvKey,
          value: kDefaultMicrosoftGraphClientId,
        ),
      );
}

Future<void> ensureGoogleClientIdKv(AppDatabase db) async {
  final row = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kGoogleClientIdKvKey)))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.configKeyValues).insert(
        ConfigKeyValuesCompanion.insert(
          key: kGoogleClientIdKvKey,
          value: '',
        ),
      );
}
