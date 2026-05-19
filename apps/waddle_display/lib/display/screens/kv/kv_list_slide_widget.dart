import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'kv_widget_base.dart';

class KvListSlideWidget extends StatelessWidget {
  const KvListSlideWidget({
    super.key,
    required this.db,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final title = cfgString(spec.config, 'title');
    final maxItems = cfgInt(spec.config, 'maxItems', 50);
    final ordered = spec.config['ordered'] == true;

    return KvWidgetBase(
      db: db,
      spec: spec,
      theme: theme,
      builder: (context, value, error) {
        final items = _coerceItems(value);
        if (items.isEmpty) {
          return Text('No list items', style: theme.textTheme.bodyMedium);
        }
        final shown = items.take(maxItems).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
            if (ordered)
              for (var i = 0; i < shown.length; i++)
                Text('${i + 1}. ${shown[i]}', style: theme.textTheme.bodyLarge)
            else
              for (final line in shown)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: theme.textTheme.bodyLarge),
                    Expanded(
                      child: Text(line, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
          ],
        );
      },
    );
  }

  List<String> _coerceItems(dynamic value) {
    if (value is List) {
      return value.map((e) => '$e').where((s) => s.isNotEmpty).toList();
    }
    if (value is Map) {
      final items = value['items'];
      if (items is List) {
        return items.map((e) => '$e').where((s) => s.isNotEmpty).toList();
      }
    }
    if (value is String) {
      return value
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
