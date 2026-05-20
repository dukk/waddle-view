import 'dart:convert';

import 'display_overlay_clock_placement.dart';

/// Resolved stock quote overlay settings from overlay `config_json`.
class StockQuoteOverlaySettings {
  const StockQuoteOverlaySettings({
    required this.placement,
    required this.symbolId,
  });

  static const StockQuoteOverlaySettings defaults = StockQuoteOverlaySettings(
    placement: ClockOverlayPlacement.defaults,
    symbolId: '',
  );

  final ClockOverlayPlacement placement;
  final String symbolId;

  Map<String, dynamic> toJson() => {
        ...placement.toJson(),
        if (symbolId.isNotEmpty) 'symbolId': symbolId,
      };

  static StockQuoteOverlaySettings parse(String configJson) {
    if (configJson.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is Map<String, dynamic>) {
        return parseMap(decoded);
      }
      if (decoded is Map) {
        return parseMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      /* fall through */
    }
    return defaults;
  }

  static StockQuoteOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    final sym = raw['symbolId'];
    return StockQuoteOverlaySettings(
      placement: ClockOverlayPlacement.parseMap(raw),
      symbolId: sym is String ? sym.trim() : '',
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates stock-quote rules.
String? normalizeStockQuoteOverlayConfigJsonString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '{}') {
    return '{}';
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on Object {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final map = decoded.cast<String, dynamic>();
  map.remove('messages');
  map.remove('message_interval_sec');
  map.remove('enabled');
  if (!_stockQuoteOverlayConfigMapValid(map)) {
    return null;
  }
  final settings = StockQuoteOverlaySettings.parseMap(map);
  return jsonEncode(settings.toJson());
}

bool _stockQuoteOverlayConfigMapValid(Map<String, dynamic> map) {
  if (!validateClockOverlayPlacementMap(map)) {
    return false;
  }
  if (!map.containsKey('symbolId') || map['symbolId'] is! String) {
    return false;
  }
  final id = (map['symbolId'] as String).trim();
  if (id.isEmpty) {
    return false;
  }
  return true;
}
