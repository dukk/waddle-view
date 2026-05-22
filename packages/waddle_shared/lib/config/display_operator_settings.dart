import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/config/adoption_allowed_roles.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_custom_themes.dart';
import 'package:waddle_shared/theme/display_custom_themes_store.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/display/display_ticker_settings.dart';
import 'package:waddle_shared/display/display_weather_temperature_unit_kv.dart';
import 'package:waddle_shared/display/display_viewport_reserve.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

/// PUT rejected when [display_theme_id] is not builtin or a stored custom theme.
class DisplayThemeUnknownIdException implements Exception {}

/// Aggregated display-level operator settings from [config_key_values].
Future<Map<String, dynamic>> readDisplayOperatorSettings(AppDatabase db) async {
  final kvRows = await db.select(db.configKeyValues).get();
  final kv = {for (final r in kvRows) r.key: r.value};
  final customThemes = parseDisplayCustomThemesFromKvValue(
    kv[kDisplayThemeCustomKvKey],
  );
  final themeId = resolveDisplayThemeId(kv[kDisplayThemeIdKvKey], customThemes);
  final screenTextScale = normalizeDisplayTextScaleOption(
    kv[kDisplayTextScaleScreenKvKey],
  );
  final tickerTextScale = normalizeDisplayTextScaleOption(
    kv[kDisplayTextScaleTickerKvKey],
  );
  final tzRaw = kv[kDisplayTimezoneKvKey]?.trim() ?? '';
  final displayTimezone = tzRaw.isEmpty ? kDefaultDisplayTimezoneIana : tzRaw;
  final programHistoryDepth = normalizeDisplayProgramHistoryDepth(
    kv[kDisplayProgramHistoryDepthKvKey],
  );
  final viewportReserve = parseDisplayViewportReservePctFromKv(kv);
  final tickerSettings = parseDisplayTickerSettingsFromKv(kv);
  final adoptionAllowedRoles = await readAdoptionAllowedRoles(db);
  final adoptionRolesList = adoptionAllowedRoles.toList()
    ..sort((a, b) {
      final ai = kAdoptionConfigurableRoles.indexOf(a);
      final bi = kAdoptionConfigurableRoles.indexOf(b);
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
  return {
    'display_theme_id': themeId,
    'display_custom_themes': displayCustomThemesToJson(customThemes),
    'display_program_history_depth': programHistoryDepth,
    'display_text_scale_screen': screenTextScale,
    'display_text_scale_ticker': tickerTextScale,
    'display_timezone': displayTimezone,
    'display_viewport_reserve_top_pct': viewportReserve.top,
    'display_viewport_reserve_right_pct': viewportReserve.right,
    'display_viewport_reserve_bottom_pct': viewportReserve.bottom,
    'display_viewport_reserve_left_pct': viewportReserve.left,
    'display_ticker_program_duration_seconds':
        tickerSettings.programDurationSeconds,
    'display_ticker_pixels_per_second': tickerSettings.pixelsPerSecond,
    'display_ticker_item_separator': tickerSettings.itemSeparator,
    'display_ticker_program_separator': tickerSettings.programSeparator,
    'display_weather_temperature_unit': displayWeatherTemperatureUnitFromKv(kv),
    'controller_time_format': normalizeControllerTimeFormat(
      kv[kControllerTimeFormatKvKey],
    ),
    'controller_date_order': normalizeControllerDateOrder(
      kv[kControllerDateOrderKvKey],
    ),
    'adoption_allowed_roles': adoptionRolesList,
    'adoption_allow_new_requests': adoptionAllowedRoles.isNotEmpty,
  };
}

/// Applies a partial PUT body. Returns false when no recognized fields were present.
Future<bool> applyDisplayOperatorSettingsPut(
  AppDatabase db,
  Map<String, dynamic> body,
) async {
  var touched = false;

  if (body.containsKey('display_theme_id')) {
    final rawId = '${body['display_theme_id']}'.trim().toLowerCase().replaceAll(
          RegExp(r'[\s-]+'),
          '_',
        );
    final customThemes = await readDisplayCustomThemes(db);
    if (!isKnownDisplayThemeId(rawId, customThemes)) {
      throw DisplayThemeUnknownIdException();
    }
    final themeId = resolveDisplayThemeId(rawId, customThemes);
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayThemeIdKvKey,
            value: themeId,
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_program_history_depth')) {
    final depth = normalizeDisplayProgramHistoryDepth(
      '${body['display_program_history_depth']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayProgramHistoryDepthKvKey,
            value: '$depth',
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_text_scale_screen')) {
    final screenTextScale = normalizeDisplayTextScaleOption(
      '${body['display_text_scale_screen']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTextScaleScreenKvKey,
            value: screenTextScale,
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_text_scale_ticker')) {
    final tickerTextScale = normalizeDisplayTextScaleOption(
      '${body['display_text_scale_ticker']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTextScaleTickerKvKey,
            value: tickerTextScale,
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_timezone')) {
    final raw = body['display_timezone'];
    final s = raw == null ? '' : '$raw'.trim();
    if (s.isEmpty) {
      await (db.delete(
        db.configKeyValues,
      )..where((t) => t.key.equals(kDisplayTimezoneKvKey))).go();
    } else {
      await db
          .into(db.configKeyValues)
          .insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kDisplayTimezoneKvKey,
              value: s,
            ),
          );
    }
    touched = true;
  }
  if (body.containsKey('display_ticker_program_duration_seconds')) {
    final seconds = normalizeDisplayTickerProgramDurationSeconds(
      '${body['display_ticker_program_duration_seconds']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTickerProgramDurationSecondsKvKey,
            value: '$seconds',
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_ticker_pixels_per_second')) {
    final px = normalizeDisplayTickerPixelsPerSecond(
      '${body['display_ticker_pixels_per_second']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTickerPixelsPerSecondKvKey,
            value: '$px',
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_ticker_item_separator')) {
    final sep = normalizeDisplayTickerSeparator(
      body['display_ticker_item_separator'],
      defaultValue: kDefaultDisplayTickerItemSeparator,
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTickerItemSeparatorKvKey,
            value: sep,
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_ticker_program_separator')) {
    final sep = normalizeDisplayTickerSeparator(
      body['display_ticker_program_separator'],
      defaultValue: kDefaultDisplayTickerProgramSeparator,
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayTickerProgramSeparatorKvKey,
            value: sep,
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_weather_temperature_unit')) {
    final unit = normalizeDisplayWeatherTemperatureUnit(
      body['display_weather_temperature_unit'],
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayWeatherTemperatureUnitKvKey,
            value: unit,
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_viewport_reserve_top_pct')) {
    final top = normalizeViewportReservePct(
      '${body['display_viewport_reserve_top_pct']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayViewportReserveTopPctKvKey,
            value: '$top',
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_viewport_reserve_right_pct')) {
    final right = normalizeViewportReservePct(
      '${body['display_viewport_reserve_right_pct']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayViewportReserveRightPctKvKey,
            value: '$right',
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_viewport_reserve_bottom_pct')) {
    final bottom = normalizeViewportReservePct(
      '${body['display_viewport_reserve_bottom_pct']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayViewportReserveBottomPctKvKey,
            value: '$bottom',
          ),
        );
    touched = true;
  }
  if (body.containsKey('display_viewport_reserve_left_pct')) {
    final left = normalizeViewportReservePct(
      '${body['display_viewport_reserve_left_pct']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kDisplayViewportReserveLeftPctKvKey,
            value: '$left',
          ),
        );
    touched = true;
  }
  if (body.containsKey('controller_time_format')) {
    final fmt = normalizeControllerTimeFormat(
      '${body['controller_time_format']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kControllerTimeFormatKvKey,
            value: fmt,
          ),
        );
    touched = true;
  }
  if (body.containsKey('controller_date_order')) {
    final order = normalizeControllerDateOrder(
      '${body['controller_date_order']}',
    );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kControllerDateOrderKvKey,
            value: order,
          ),
        );
    touched = true;
  }
  if (body.containsKey('adoption_allowed_roles')) {
    final raw = body['adoption_allowed_roles'];
    final roles = <String>{};
    if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          final role = item.trim();
          if (isValidUserRole(role)) {
            roles.add(role);
          }
        }
      }
    }
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowedRolesKvKey,
            value: encodeAdoptionAllowedRoles(roles),
          ),
        );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowNewRequestsKvKey,
            value: roles.isEmpty ? 'false' : 'true',
          ),
        );
    touched = true;
  } else if (body.containsKey('adoption_allow_new_requests')) {
    final raw = body['adoption_allow_new_requests'];
    final flag = raw is bool ? raw : raw?.toString().toLowerCase() == 'true';
    final roles = flag ? Set<String>.from(kValidUserRoles) : <String>{};
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowedRolesKvKey,
            value: encodeAdoptionAllowedRoles(roles),
          ),
        );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowNewRequestsKvKey,
            value: flag ? 'true' : 'false',
          ),
        );
    touched = true;
  }
  return touched;
}
