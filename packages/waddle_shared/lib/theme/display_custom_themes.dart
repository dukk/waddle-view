import 'dart:convert';

import 'display_theme_ids.dart';
import 'display_theme_kv.dart';

/// Max custom themes stored per display.
const int kDisplayCustomThemeMaxCount = 20;

/// Max label length for a custom theme.
const int kDisplayCustomThemeMaxLabelLength = 64;

/// Min/max gradient stops per chrome group (except accents).
const int kDisplayThemeChromeMinStops = 2;
const int kDisplayThemeChromeMaxStops = 4;

const int kDisplayThemeAccentCount = 4;

const String kDisplayCustomThemeIdPrefix = 'custom_';

final RegExp _hexColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Role-grouped hex colors for TV chrome (matches controller preview shape).
class DisplayThemeChromeGroups {
  const DisplayThemeChromeGroups({
    required this.display,
    required this.primaryContainer,
    required this.secondaryContainer,
    required this.accents,
  });

  final List<String> display;
  final List<String> primaryContainer;
  final List<String> secondaryContainer;
  final List<String> accents;

  Map<String, dynamic> toJson() => {
        'display': List<String>.from(display),
        'primaryContainer': List<String>.from(primaryContainer),
        'secondaryContainer': List<String>.from(secondaryContainer),
        'accents': List<String>.from(accents),
      };

  /// API / settings shape uses `preview` key.
  Map<String, dynamic> toPreviewJson() => toJson();
}

/// Operator-defined theme persisted under [kDisplayThemeCustomKvKey].
class DisplayCustomTheme {
  const DisplayCustomTheme({
    required this.id,
    required this.label,
    required this.chrome,
  });

  final String id;
  final String label;
  final DisplayThemeChromeGroups chrome;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'preview': chrome.toPreviewJson(),
      };

  DisplayThemeChromeGroups get preview => chrome;
}

/// Thrown when chrome groups or label fail validation.
class DisplayThemeValidationException implements Exception {
  DisplayThemeValidationException(this.code, [this.detail]);

  final String code;
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}

/// Parses [raw] JSON array from [kDisplayThemeCustomKvKey].
List<DisplayCustomTheme> parseDisplayCustomThemesFromKvValue(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    final out = <DisplayCustomTheme>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final id = '${map['id']}'.trim();
      final label = '${map['label']}'.trim();
      final previewRaw = map['preview'] ?? map['chrome'];
      if (id.isEmpty || label.isEmpty || previewRaw is! Map) {
        continue;
      }
      try {
        final chrome = parseDisplayThemeChromeGroups(
          Map<String, dynamic>.from(previewRaw),
        );
        out.add(DisplayCustomTheme(id: id, label: label, chrome: chrome));
      } on DisplayThemeValidationException {
        continue;
      }
    }
    return out;
  } catch (_) {
    return const [];
  }
}

String encodeDisplayCustomThemes(List<DisplayCustomTheme> themes) {
  return jsonEncode(themes.map((t) => t.toJson()).toList());
}

/// Validates and normalizes hex list for a gradient group.
List<String> parseHexColorList(
  dynamic raw, {
  required int minLength,
  required int maxLength,
  required String fieldName,
}) {
  if (raw is! List) {
    throw DisplayThemeValidationException(
      'invalid_display_theme_preview',
      '$fieldName must be an array',
    );
  }
  if (raw.length < minLength || raw.length > maxLength) {
    throw DisplayThemeValidationException(
      'invalid_display_theme_preview',
      '$fieldName needs $minLength–$maxLength colors',
    );
  }
  final out = <String>[];
  for (final item in raw) {
    final s = '$item'.trim().toUpperCase();
    final normalized = s.startsWith('#') ? s : '#$s';
    if (!_hexColorPattern.hasMatch(normalized)) {
      throw DisplayThemeValidationException(
        'invalid_display_theme_preview',
        'invalid hex in $fieldName',
      );
    }
    out.add(normalized);
  }
  return out;
}

DisplayThemeChromeGroups parseDisplayThemeChromeGroups(Map<String, dynamic> map) {
  return DisplayThemeChromeGroups(
    display: parseHexColorList(
      map['display'],
      minLength: kDisplayThemeChromeMinStops,
      maxLength: kDisplayThemeChromeMaxStops,
      fieldName: 'display',
    ),
    primaryContainer: parseHexColorList(
      map['primaryContainer'],
      minLength: kDisplayThemeChromeMinStops,
      maxLength: kDisplayThemeChromeMaxStops,
      fieldName: 'primaryContainer',
    ),
    secondaryContainer: parseHexColorList(
      map['secondaryContainer'],
      minLength: kDisplayThemeChromeMinStops,
      maxLength: kDisplayThemeChromeMaxStops,
      fieldName: 'secondaryContainer',
    ),
    accents: parseHexColorList(
      map['accents'],
      minLength: kDisplayThemeAccentCount,
      maxLength: kDisplayThemeAccentCount,
      fieldName: 'accents',
    ),
  );
}

String normalizeDisplayThemeLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw DisplayThemeValidationException(
      'invalid_display_theme_preview',
      'label is required',
    );
  }
  if (trimmed.length > kDisplayCustomThemeMaxLabelLength) {
    throw DisplayThemeValidationException(
      'invalid_display_theme_preview',
      'label too long',
    );
  }
  return trimmed;
}

String slugifyDisplayThemeLabel(String label) {
  var slug = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  slug = slug.replaceAll(RegExp(r'_+'), '_');
  slug = slug.replaceAll(RegExp(r'^_|_$'), '');
  if (slug.isEmpty) {
    slug = 'theme';
  }
  if (slug.length > 40) {
    slug = slug.substring(0, 40);
  }
  return slug;
}

/// Allocates `custom_<slug>` unique against [existingIds] and builtin set.
String allocateDisplayCustomThemeId(
  String label,
  Set<String> existingIds,
) {
  final base = '$kDisplayCustomThemeIdPrefix${slugifyDisplayThemeLabel(label)}';
  if (!existingIds.contains(base) && !kRegisteredDisplayThemeIdSet.contains(base)) {
    return base;
  }
  var n = 2;
  while (true) {
    final candidate = '${base}_$n';
    if (!existingIds.contains(candidate) &&
        !kRegisteredDisplayThemeIdSet.contains(candidate)) {
      return candidate;
    }
    n++;
  }
}

bool isBuiltinDisplayThemeId(String id) =>
    kRegisteredDisplayThemeIdSet.contains(id);

bool isCustomDisplayThemeId(String id) =>
    id.startsWith(kDisplayCustomThemeIdPrefix);

/// Whether [id] is a builtin or listed custom theme.
bool isKnownDisplayThemeId(String id, List<DisplayCustomTheme> customThemes) {
  if (isBuiltinDisplayThemeId(id)) {
    return true;
  }
  return customThemes.any((t) => t.id == id);
}

/// Resolves raw KV / API value to a builtin or custom id, else default.
String resolveDisplayThemeId(
  String? raw,
  List<DisplayCustomTheme> customThemes,
) {
  if (raw == null) {
    return kDefaultDisplayThemeId;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return kDefaultDisplayThemeId;
  }
  final id = trimmed.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  if (kRegisteredDisplayThemeIdSet.contains(id)) {
    return id;
  }
  if (customThemes.any((t) => t.id == id)) {
    return id;
  }
  return kDefaultDisplayThemeId;
}

DisplayCustomTheme? findDisplayCustomTheme(
  List<DisplayCustomTheme> themes,
  String id,
) {
  for (final t in themes) {
    if (t.id == id) {
      return t;
    }
  }
  return null;
}
