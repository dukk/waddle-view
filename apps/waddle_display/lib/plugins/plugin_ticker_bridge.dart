import 'dart:convert';

import '../curator/curator_read_port.dart';
import '../curator/ticker_curation.dart' show parseTickerTapeFallbackText;
import '../curator/ticker_item.dart';

/// Plugin ticker tapes use `fallback_text` in config or KV written by collect.
class PluginTickerBridge {
  static List<TickerItem> expand(TickerTapeForCuration def) {
    final config = _parseConfig(def.configJson);
    final pluginId = (config['plugin_id'] as String?)?.trim();
    final kvKey = pluginId != null && pluginId.isNotEmpty
        ? 'ticker.marquee.$pluginId'
        : null;
    final fallback = parseTickerTapeFallbackText(def.configJson) ?? '';
    final body = fallback.isNotEmpty ? fallback : 'Plugin ticker (${def.id})';
    return [
      TickerItem(
        kind: 'custom',
        body: body,
        sourceId: kvKey ?? 'plugin:${def.id}',
      ),
    ];
  }

  static Map<String, dynamic> _parseConfig(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) {
        return v;
      }
    } on Object {
      // ignore
    }
    return const {};
  }
}
