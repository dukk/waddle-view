import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/config/display_operator_settings.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

import '../helpers/memory_database.dart';

void main() {
  test('readDisplayOperatorSettings includes datetime format defaults after seed', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final body = await readDisplayOperatorSettings(db);
    expect(body['controller_time_format'], kDefaultControllerTimeFormat);
    expect(body['controller_date_order'], kDefaultControllerDateOrder);
    expect(body['display_theme_id'], isNotEmpty);
    expect(body['display_timezone'], isNotEmpty);
    expect(body['display_program_history_depth'], kDefaultDisplayProgramHistoryDepth);
    expect(body['display_viewport_reserve_top_pct'], 0);
    expect(body['display_viewport_reserve_right_pct'], 0);
    expect(body['display_viewport_reserve_bottom_pct'], 0);
    expect(body['display_viewport_reserve_left_pct'], 0);
    expect(body.containsKey('display_image_overlay'), isFalse);
  });

  test('applyDisplayOperatorSettingsPut round-trips theme and datetime format', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final touched = await applyDisplayOperatorSettingsPut(db, {
      'display_theme_id': 'graphite_amber',
      'controller_time_format': '24h',
      'controller_date_order': 'dmy',
    });
    expect(touched, isTrue);

    final body = await readDisplayOperatorSettings(db);
    expect(body['display_theme_id'], 'graphite_amber');
    expect(body['controller_time_format'], kControllerTimeFormat24h);
    expect(body['controller_date_order'], kControllerDateOrderDmy);
  });

  test('applyDisplayOperatorSettingsPut round-trips viewport reserve pct', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final touched = await applyDisplayOperatorSettingsPut(db, {
      'display_viewport_reserve_top_pct': 12,
      'display_viewport_reserve_right_pct': 5,
      'display_viewport_reserve_bottom_pct': 3,
      'display_viewport_reserve_left_pct': 8,
    });
    expect(touched, isTrue);

    final body = await readDisplayOperatorSettings(db);
    expect(body['display_viewport_reserve_top_pct'], 12);
    expect(body['display_viewport_reserve_right_pct'], 5);
    expect(body['display_viewport_reserve_bottom_pct'], 3);
    expect(body['display_viewport_reserve_left_pct'], 8);

    final kv = await db.select(db.configKeyValues).get();
    final map = {for (final r in kv) r.key: r.value};
    expect(map[kDisplayViewportReserveTopPctKvKey], '12');
  });

  test('applyDisplayOperatorSettingsPut round-trips program history depth', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final touched = await applyDisplayOperatorSettingsPut(db, {
      'display_program_history_depth': 8,
    });
    expect(touched, isTrue);

    final body = await readDisplayOperatorSettings(db);
    expect(body['display_program_history_depth'], 8);
  });

  test('applyDisplayOperatorSettingsPut returns false when body has no recognized keys', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayThemeIdKvKey,
            value: kDefaultDisplayThemeId,
          ),
        );

    final touched = await applyDisplayOperatorSettingsPut(db, {'unknown': 1});
    expect(touched, isFalse);
  });
}
