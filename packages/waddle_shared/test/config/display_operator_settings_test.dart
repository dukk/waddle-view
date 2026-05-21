import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/config/display_operator_settings.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_shared/display/display_ticker_settings.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

import '../helpers/memory_database.dart';

void main() {
  test(
    'readDisplayOperatorSettings includes datetime format defaults after seed',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await ensureInitialSeed(db);

      final body = await readDisplayOperatorSettings(db);
      expect(body['controller_time_format'], kDefaultControllerTimeFormat);
      expect(body['controller_date_order'], kDefaultControllerDateOrder);
      expect(body['display_theme_id'], isNotEmpty);
      expect(body['display_timezone'], isNotEmpty);
      expect(
        body['display_program_history_depth'],
        kDefaultDisplayProgramHistoryDepth,
      );
      expect(body['display_viewport_reserve_top_pct'], 0);
      expect(body['display_viewport_reserve_right_pct'], 0);
      expect(body['display_viewport_reserve_bottom_pct'], 0);
      expect(body['display_viewport_reserve_left_pct'], 0);
      expect(
        body['display_ticker_program_duration_seconds'],
        kDisplayTickerProgramDurationSecondsDefault,
      );
      expect(
        body['display_ticker_pixels_per_second'],
        kDisplayTickerPixelsPerSecondDefault,
      );
      expect(body.containsKey('display_image_overlay'), isFalse);
    },
  );

  test(
    'applyDisplayOperatorSettingsPut round-trips theme and datetime format',
    () async {
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
    },
  );

  test(
    'applyDisplayOperatorSettingsPut round-trips viewport reserve pct',
    () async {
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
    },
  );

  test(
    'applyDisplayOperatorSettingsPut round-trips ticker duration and pixels per second',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await ensureInitialSeed(db);

      final touched = await applyDisplayOperatorSettingsPut(db, {
        'display_ticker_program_duration_seconds': 600,
        'display_ticker_pixels_per_second': 100,
      });
      expect(touched, isTrue);

      final body = await readDisplayOperatorSettings(db);
      expect(body['display_ticker_program_duration_seconds'], 600);
      expect(body['display_ticker_pixels_per_second'], 100);

      final kv = await db.select(db.configKeyValues).get();
      final map = {for (final r in kv) r.key: r.value};
      expect(map[kDisplayTickerProgramDurationSecondsKvKey], '600');
      expect(map[kDisplayTickerPixelsPerSecondKvKey], '100');
    },
  );

  test(
    'applyDisplayOperatorSettingsPut round-trips program history depth',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await ensureInitialSeed(db);

      final touched = await applyDisplayOperatorSettingsPut(db, {
        'display_program_history_depth': 8,
      });
      expect(touched, isTrue);

      final body = await readDisplayOperatorSettings(db);
      expect(body['display_program_history_depth'], 8);
    },
  );

  test(
    'applyDisplayOperatorSettingsPut returns false when body has no recognized keys',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await db
          .into(db.configKeyValues)
          .insert(
            ConfigKeyValuesCompanion.insert(
              key: kDisplayThemeIdKvKey,
              value: kDefaultDisplayThemeId,
            ),
          );

      final touched = await applyDisplayOperatorSettingsPut(db, {'unknown': 1});
      expect(touched, isFalse);
    },
  );

  test('applyDisplayOperatorSettingsPut round-trips text scales', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final touched = await applyDisplayOperatorSettingsPut(db, {
      'display_text_scale_screen': 'large',
      'display_text_scale_ticker': 'small',
    });
    expect(touched, isTrue);

    final body = await readDisplayOperatorSettings(db);
    expect(body['display_text_scale_screen'], kDisplayTextScaleLarge);
    expect(body['display_text_scale_ticker'], kDisplayTextScaleSmall);
  });

  test(
    'applyDisplayOperatorSettingsPut empty timezone deletes kv and read uses default',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await ensureInitialSeed(db);

      await applyDisplayOperatorSettingsPut(db, {
        'display_timezone': 'America/Chicago',
      });
      await applyDisplayOperatorSettingsPut(db, {'display_timezone': ''});

      final tzRow = await (db.select(
        db.configKeyValues,
      )..where((t) => t.key.equals(kDisplayTimezoneKvKey))).getSingleOrNull();
      expect(tzRow, isNull);

      final body = await readDisplayOperatorSettings(db);
      expect(body['display_timezone'], kDefaultDisplayTimezoneIana);
    },
  );

  test(
    'adoption_allowed_roles filters invalid roles and sorts configurable order',
    () async {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      await ensureInitialSeed(db);

      await applyDisplayOperatorSettingsPut(db, {
        'adoption_allowed_roles': [
          kUserRoleAdmin,
          'not_a_role',
          kUserRoleViewer,
        ],
      });

      final body = await readDisplayOperatorSettings(db);
      expect(body['adoption_allowed_roles'], [kUserRoleViewer, kUserRoleAdmin]);
      expect(body['adoption_allow_new_requests'], isTrue);
    },
  );

  test('adoption_allow_new_requests false clears roles', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    await applyDisplayOperatorSettingsPut(db, {
      'adoption_allow_new_requests': false,
    });

    final body = await readDisplayOperatorSettings(db);
    expect(body['adoption_allowed_roles'], isEmpty);
    expect(body['adoption_allow_new_requests'], isFalse);
  });

  test('adoption_allow_new_requests true grants all valid roles', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    await applyDisplayOperatorSettingsPut(db, {
      'adoption_allow_new_requests': false,
    });
    await applyDisplayOperatorSettingsPut(db, {
      'adoption_allow_new_requests': true,
    });

    final body = await readDisplayOperatorSettings(db);
    expect((body['adoption_allowed_roles'] as List).toSet(), kValidUserRoles);
    expect(body['adoption_allow_new_requests'], isTrue);
  });
}
