import 'dart:convert';

/// Config defaults for summary capacity hints (used by curator + widgets).
int defaultSummaryCapacityCharsFor(String type, Map<String, dynamic> config) {
  switch (type) {
    case 'news':
      return _cfgInt(config, 'summaryCapacityChars', 1200);
    case 'news_columns':
      return _cfgInt(config, 'summaryCapacityCharsPerColumn', 220);
    case 'news_stack':
      return _cfgInt(config, 'summaryCapacityCharsPerSlot', 320);
    default:
      return 0;
  }
}

int _cfgInt(Map<String, dynamic> c, String key, int def) {
  final v = c[key];
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  return def;
}

int _rssArticleColumnCount(Map<String, dynamic> config) {
  final v = config['columnCount'];
  if (v is int) {
    return v.clamp(1, 6);
  }
  if (v is double) {
    return v.round().clamp(1, 6);
  }
  return 3;
}

/// Per-slot summary capacity for RSS widgets (chars). Empty for non-RSS types.
List<int> computeRssSummarySlotCapacities(String type, Map<String, dynamic> config) {
  switch (type) {
    case 'news':
      return [defaultSummaryCapacityCharsFor(type, config)];
    case 'news_columns':
      final n = _rssArticleColumnCount(config);
      final per = defaultSummaryCapacityCharsFor(type, config);
      return List<int>.filled(n, per);
    case 'news_stack':
      final per = defaultSummaryCapacityCharsFor(type, config);
      return List<int>.filled(2, per);
    default:
      return const [];
  }
}

/// One widget entry from synthesized layout JSON (see [synthesizeLayoutJson]).
class ParsedWidgetSpec {
  const ParsedWidgetSpec({
    required this.type,
    required this.slot,
    required this.config,
    this.rssSummarySlotCapacities = const [],
  });

  final String type;
  final String slot;
  final Map<String, dynamic> config;

  /// For `news` / `news_columns` / `news_stack`: capacity
  /// per slot (chars). Empty for other widget types.
  final List<int> rssSummarySlotCapacities;

  String get choiceKey => '${slot}_$type';
}

/// First widget's type and [config] as JSON text; empty/malformed → `static_text` / `{}`.
///
/// Used when migrating legacy [ScreenDefinitions.layout_json] (v26 and earlier).
/// If multiple widgets were present, only the first is preserved.
({String screenType, String configJson}) extractLegacyScreenFields(
  String layoutJson,
) {
  final specs = parseScreenLayoutWidgets(layoutJson);
  if (specs.isEmpty) {
    return (screenType: 'static_text', configJson: '{}');
  }
  final w = specs.first;
  return (screenType: w.type, configJson: jsonEncode(w.config));
}

/// Builds the layout document expected by [parseScreenLayoutWidgets] from DB columns.
String synthesizeLayoutJson({
  required String screenType,
  required String configJson,
  String slot = 'main',
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(configJson);
  } catch (_) {
    decoded = <String, dynamic>{};
  }
  if (decoded is! Map<String, dynamic>) {
    decoded = <String, dynamic>{};
  }
  return jsonEncode({
    'v': 1,
    'layout': 'single',
    'widgets': [
      {'type': screenType, 'slot': slot, 'config': decoded},
    ],
  });
}

/// Parses `widgets` array from layout JSON; ignores malformed entries.
List<ParsedWidgetSpec> parseScreenLayoutWidgets(String layoutJson) {
  try {
    final decoded = jsonDecode(layoutJson);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }
    final raw = decoded['widgets'];
    if (raw is! List<dynamic>) {
      return const [];
    }
    final out = <ParsedWidgetSpec>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) {
        continue;
      }
      final type = e['type'];
      final slot = e['slot'];
      if (type is! String || slot is! String) {
        continue;
      }
      final config = e['config'];
      final cfg = config is Map<String, dynamic>
          ? Map<String, dynamic>.from(config)
          : const <String, dynamic>{};
      out.add(
        ParsedWidgetSpec(
          type: type,
          slot: slot,
          config: cfg,
          rssSummarySlotCapacities: computeRssSummarySlotCapacities(type, cfg),
        ),
      );
    }
    return out;
  } catch (_) {
    return const [];
  }
}
