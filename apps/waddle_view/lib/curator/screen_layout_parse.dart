import 'dart:convert';

/// One widget entry from [ScreenDefinitions.layoutJson].
class ParsedWidgetSpec {
  const ParsedWidgetSpec({
    required this.type,
    required this.slot,
    required this.config,
  });

  final String type;
  final String slot;
  final Map<String, dynamic> config;

  String get choiceKey => '${slot}_$type';
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
      out.add(
        ParsedWidgetSpec(
          type: type,
          slot: slot,
          config: config is Map<String, dynamic>
              ? Map<String, dynamic>.from(config)
              : const <String, dynamic>{},
        ),
      );
    }
    return out;
  } catch (_) {
    return const [];
  }
}
