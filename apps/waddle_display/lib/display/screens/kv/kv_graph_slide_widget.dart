import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'kv_widget_base.dart';

/// Simple node list visualization (force-free layout).
class KvGraphSlideWidget extends StatelessWidget {
  const KvGraphSlideWidget({
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
    return KvWidgetBase(
      db: db,
      spec: spec,
      theme: theme,
      builder: (context, value, error) {
        if (value is! Map) {
          return Text('Expected graph object', style: theme.textTheme.bodyMedium);
        }
        final nodes = value['nodes'];
        final edges = value['edges'];
        final nodeList = nodes is List ? nodes : const [];
        final edgeList = edges is List ? edges : const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nodes (${nodeList.length})', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in nodeList)
                  if (n is Map)
                    Chip(
                      label: Text(
                        '${n['label'] ?? n['id'] ?? '?'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Edges (${edgeList.length})', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final e in edgeList.take(12))
              if (e is Map)
                Text(
                  '${e['from']} → ${e['to']}',
                  style: theme.textTheme.bodyMedium,
                ),
          ],
        );
      },
    );
  }
}
