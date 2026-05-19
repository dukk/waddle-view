import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/config/display_image_overlay_kv.dart';
import 'package:waddle_shared/config/display_operator_settings.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';
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
    expect(body['display_image_overlay'], isA<Map<String, dynamic>>());
    expect(
      (body['display_image_overlay'] as Map)['enabled'],
      DisplayImageOverlaySettings.defaults.enabled,
    );
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

  test('applyDisplayOperatorSettingsPut round-trips display_image_overlay', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await ensureInitialSeed(db);

    final touched = await applyDisplayOperatorSettingsPut(db, {
      'display_image_overlay': {
        'enabled': true,
        'image_blob_key': kOverlayBlobKeyDuckMascot,
        'x': 0.85,
        'y': 0.05,
        'scale': 0.18,
        'opacity': 0.7,
      },
    });
    expect(touched, isTrue);

    final body = await readDisplayOperatorSettings(db);
    final overlay = body['display_image_overlay'] as Map<String, dynamic>;
    expect(overlay['enabled'], isTrue);
    expect(overlay['image_blob_key'], kOverlayBlobKeyDuckMascot);
    expect(overlay['x'], 0.85);
    expect(overlay['opacity'], 0.7);
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
