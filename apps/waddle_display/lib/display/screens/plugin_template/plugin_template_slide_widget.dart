import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

/// JSON-driven slide for plugin sidecar state (`title`, `metrics`, `body`).
class PluginTemplateSlideWidget extends StatelessWidget {
  const PluginTemplateSlideWidget({
    super.key,
    required this.spec,
    required this.theme,
  });

  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final config = _parse(spec.config);
    final title = (config['title'] as String?)?.trim() ?? 'Plugin';
    final body = (config['body'] as String?)?.trim() ?? '';
    final metrics = config['metrics'];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(body, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
          if (metrics is List && metrics.isNotEmpty) ...[
            const SizedBox(height: 24),
            for (final m in metrics)
              if (m is Map)
                Text(
                  '${m['label'] ?? ''}: ${m['value'] ?? ''}',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _parse(Map<String, dynamic> raw) {
    if (raw.containsKey('state_json') && raw['state_json'] is String) {
      try {
        final v = jsonDecode(raw['state_json'] as String);
        if (v is Map<String, dynamic>) {
          return v;
        }
      } on Object {
        // ignore
      }
    }
    return raw;
  }
}
