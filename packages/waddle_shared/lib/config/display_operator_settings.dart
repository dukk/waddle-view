import 'package:drift/drift.dart' show Value;
import 'package:waddle_shared/auth/role_permissions.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/config/adoption_allowed_roles.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

/// Aggregated display-level operator settings from [config_key_values].
Future<Map<String, dynamic>> readDisplayOperatorSettings(AppDatabase db) async {
  final kvRows = await db.select(db.configKeyValues).get();
  final kv = {for (final r in kvRows) r.key: r.value};
  final themeId = normalizeDisplayThemeId(kv[kDisplayThemeIdKvKey]);
  final screenTextScale = normalizeDisplayTextScaleOption(
    kv[kDisplayTextScaleScreenKvKey],
  );
  final tickerTextScale = normalizeDisplayTextScaleOption(
    kv[kDisplayTextScaleTickerKvKey],
  );
  final tzRaw = kv[kDisplayTimezoneKvKey]?.trim() ?? '';
  final displayTimezone =
      tzRaw.isEmpty ? kDefaultDisplayTimezoneIana : tzRaw;
  final programHistoryDepth = normalizeDisplayProgramHistoryDepth(
    kv[kDisplayProgramHistoryDepthKvKey],
  );
  final adoptionAllowedRoles = await readAdoptionAllowedRoles(db);
  final adoptionRolesList = adoptionAllowedRoles.toList()
    ..sort((a, b) {
      final ai = kAdoptionConfigurableRoles.indexOf(a);
      final bi = kAdoptionConfigurableRoles.indexOf(b);
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
  return {
    'display_theme_id': themeId,
    'display_program_history_depth': programHistoryDepth,
    'display_text_scale_screen': screenTextScale,
    'display_text_scale_ticker': tickerTextScale,
    'display_timezone': displayTimezone,
    'controller_time_format':
        normalizeControllerTimeFormat(kv[kControllerTimeFormatKvKey]),
    'controller_date_order':
        normalizeControllerDateOrder(kv[kControllerDateOrderKvKey]),
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
    final themeId = normalizeDisplayThemeId('${body['display_theme_id']}');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
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
    await db.into(db.configKeyValues).insertOnConflictUpdate(
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
    await db.into(db.configKeyValues).insertOnConflictUpdate(
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
    await db.into(db.configKeyValues).insertOnConflictUpdate(
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
      await (db.delete(db.configKeyValues)
            ..where((t) => t.key.equals(kDisplayTimezoneKvKey)))
          .go();
    } else {
      await db.into(db.configKeyValues).insertOnConflictUpdate(
            ConfigKeyValuesCompanion.insert(
              key: kDisplayTimezoneKvKey,
              value: s,
            ),
          );
    }
    touched = true;
  }
  if (body.containsKey('controller_time_format')) {
    final fmt = normalizeControllerTimeFormat('${body['controller_time_format']}');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kControllerTimeFormatKvKey,
            value: fmt,
          ),
        );
    touched = true;
  }
  if (body.containsKey('controller_date_order')) {
    final order = normalizeControllerDateOrder('${body['controller_date_order']}');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
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
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowedRolesKvKey,
            value: encodeAdoptionAllowedRoles(roles),
          ),
        );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
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
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowedRolesKvKey,
            value: encodeAdoptionAllowedRoles(roles),
          ),
        );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kAdoptionAllowNewRequestsKvKey,
            value: flag ? 'true' : 'false',
          ),
        );
    touched = true;
  }
  return touched;
}
