import 'dart:convert';

/// JSON map in [config_key_values]: severity (lowercase key) → Material icon name
/// (underscore form, same vocabulary as content-category icons plus alert defaults).
const String kAlertSeverityIconsKvKey = 'display.alert.severity_icons';

const Map<String, String> kDefaultAlertSeverityMaterialNames = {
  'info': 'info_outline',
  'auth': 'lock_outline',
  'security': 'security',
  'warning': 'warning_amber_rounded',
  'error': 'error_outline',
  'critical': 'report_problem_outlined',
};

final String kDefaultAlertSeverityIconsJson =
    jsonEncode(kDefaultAlertSeverityMaterialNames);

/// Merges [raw] JSON object over [kDefaultAlertSeverityMaterialNames].
Map<String, String> parseAlertSeverityIconsKv(String? raw) {
  final out = Map<String, String>.from(kDefaultAlertSeverityMaterialNames);
  if (raw == null || raw.trim().isEmpty) {
    return out;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return out;
    }
    for (final e in decoded.entries) {
      final k = e.key?.toString().trim().toLowerCase();
      final v = e.value?.toString().trim();
      if (k != null && k.isNotEmpty && v != null && v.isNotEmpty) {
        out[k] = v;
      }
    }
  } on Object {
    // keep defaults
  }
  return out;
}
