import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'display_custom_themes.dart';
import 'display_theme_ids.dart';
import 'display_theme_kv.dart';

/// Reads custom themes from [kDisplayThemeCustomKvKey].
Future<List<DisplayCustomTheme>> readDisplayCustomThemes(AppDatabase db) async {
  final row = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kDisplayThemeCustomKvKey)))
      .getSingleOrNull();
  return parseDisplayCustomThemesFromKvValue(row?.value);
}

Future<void> writeDisplayCustomThemes(
  AppDatabase db,
  List<DisplayCustomTheme> themes,
) async {
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kDisplayThemeCustomKvKey,
          value: encodeDisplayCustomThemes(themes),
        ),
      );
}

/// Creates a theme; throws [DisplayThemeValidationException] or limit errors.
Future<DisplayCustomTheme> createDisplayCustomTheme(
  AppDatabase db, {
  required String label,
  required DisplayThemeChromeGroups chrome,
}) async {
  normalizeDisplayThemeLabel(label);
  final existing = await readDisplayCustomThemes(db);
  if (existing.length >= kDisplayCustomThemeMaxCount) {
    throw DisplayThemeValidationException('display_theme_limit_reached');
  }
  final ids = existing.map((t) => t.id).toSet();
  final id = allocateDisplayCustomThemeId(label, ids);
  final theme = DisplayCustomTheme(
    id: id,
    label: normalizeDisplayThemeLabel(label),
    chrome: chrome,
  );
  await writeDisplayCustomThemes(db, [...existing, theme]);
  return theme;
}

/// Updates custom theme by id.
Future<DisplayCustomTheme> updateDisplayCustomTheme(
  AppDatabase db,
  String id, {
  String? label,
  DisplayThemeChromeGroups? chrome,
}) async {
  if (!isCustomDisplayThemeId(id) || isBuiltinDisplayThemeId(id)) {
    throw DisplayThemeValidationException('display_theme_not_custom');
  }
  final existing = await readDisplayCustomThemes(db);
  final index = existing.indexWhere((t) => t.id == id);
  if (index < 0) {
    throw DisplayThemeValidationException('display_theme_not_found');
  }
  final current = existing[index];
  final next = DisplayCustomTheme(
    id: id,
    label: label != null ? normalizeDisplayThemeLabel(label) : current.label,
    chrome: chrome ?? current.chrome,
  );
  final updated = [...existing]..[index] = next;
  await writeDisplayCustomThemes(db, updated);
  return next;
}

/// Deletes custom theme; resets active theme id when it matched.
Future<void> deleteDisplayCustomTheme(AppDatabase db, String id) async {
  if (!isCustomDisplayThemeId(id) || isBuiltinDisplayThemeId(id)) {
    throw DisplayThemeValidationException('display_theme_not_custom');
  }
  final existing = await readDisplayCustomThemes(db);
  if (!existing.any((t) => t.id == id)) {
    throw DisplayThemeValidationException('display_theme_not_found');
  }
  await writeDisplayCustomThemes(
    db,
    existing.where((t) => t.id != id).toList(),
  );

  final activeRow = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kDisplayThemeIdKvKey)))
      .getSingleOrNull();
  final active = activeRow?.value.trim() ?? '';
  if (active == id) {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayThemeIdKvKey,
            value: kDefaultDisplayThemeId,
          ),
        );
  }
}

List<Map<String, dynamic>> displayCustomThemesToJson(
  List<DisplayCustomTheme> themes,
) {
  return themes.map((t) => t.toJson()).toList();
}
