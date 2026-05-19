import 'package:flutter/material.dart';
import 'package:waddle_shared/integrations/integration_kv_read.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Resolves integration KV data for [ParsedWidgetSpec] config.
class KvWidgetBase extends StatelessWidget {
  const KvWidgetBase({
    super.key,
    required this.db,
    required this.spec,
    required this.theme,
    required this.builder,
  });

  final AppDatabase db;
  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final Widget Function(BuildContext context, dynamic value, String? error) builder;

  @override
  Widget build(BuildContext context) {
    final integrationId = (spec.config['integrationId'] as String?)?.trim() ?? '';
    final valueKey = (spec.config['valueKey'] as String?)?.trim() ?? '';
    final jsonPath = (spec.config['jsonPath'] as String?)?.trim();
    final emptyText =
        (spec.config['emptyText'] as String?)?.trim() ?? 'No data yet';

    if (integrationId.isEmpty || valueKey.isEmpty) {
      return _message('Missing integrationId or valueKey');
    }

    return StreamBuilder<String?>(
      stream: watchIntegrationKvValue(
        db,
        integrationId: integrationId,
        valueKey: valueKey,
      ),
      builder: (context, snap) {
        final raw = snap.data;
        if (raw == null || raw.trim().isEmpty) {
          return _message(emptyText);
        }
        final root = parseIntegrationJsonValue(raw);
        final selected = selectJsonPath(root, jsonPath);
        if (selected == null) {
          return _message('No value at path');
        }
        return builder(context, selected, null);
      },
    );
  }

  Widget _message(String text) {
    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

String? cfgString(Map<String, dynamic> config, String key) {
  final v = config[key];
  if (v is String && v.trim().isNotEmpty) {
    return v.trim();
  }
  return null;
}

int cfgInt(Map<String, dynamic> config, String key, int def) {
  final v = config[key];
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  return def;
}

double? cfgDouble(Map<String, dynamic> config, String key) {
  final v = config[key];
  if (v is num) {
    return v.toDouble();
  }
  return null;
}
