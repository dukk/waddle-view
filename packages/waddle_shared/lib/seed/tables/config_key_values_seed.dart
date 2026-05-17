import 'package:waddle_shared/alerts/alert_severity_icons_kv.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

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
