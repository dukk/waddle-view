import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'kv_widget_base.dart';

class KvImageSlideWidget extends StatelessWidget {
  const KvImageSlideWidget({
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
    final urlPath = cfgString(spec.config, 'urlPath');

    return KvWidgetBase(
      db: db,
      spec: spec,
      theme: theme,
      builder: (context, value, error) {
        final url = _readUrl(value, urlPath);
        if (url == null || url.isEmpty) {
          return Text('No image URL', style: theme.textTheme.bodyMedium);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              'Image failed to load',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }

  String? _readUrl(dynamic value, String? urlPath) {
    if (urlPath != null && value is Map) {
      final key = urlPath.replaceFirst(r'$.', '');
      final inner = value[key];
      if (inner is String) {
        return inner;
      }
    }
    if (value is String) {
      return value;
    }
    if (value is Map && value['url'] is String) {
      return value['url'] as String;
    }
    return null;
  }
}
