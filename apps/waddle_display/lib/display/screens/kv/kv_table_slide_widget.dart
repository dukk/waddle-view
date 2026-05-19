import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'kv_widget_base.dart';

class KvTableSlideWidget extends StatelessWidget {
  const KvTableSlideWidget({
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
    final maxRows = cfgInt(spec.config, 'maxRows', 20);
    final columnsRaw = spec.config['columns'];
    final columns = <({String field, String label})>[];
    if (columnsRaw is List) {
      for (final c in columnsRaw) {
        if (c is Map) {
          final field = c['field']?.toString().trim() ?? '';
          if (field.isEmpty) {
            continue;
          }
          final label = c['label']?.toString().trim() ?? field;
          columns.add((field: field, label: label));
        }
      }
    }

    return KvWidgetBase(
      db: db,
      spec: spec,
      theme: theme,
      builder: (context, value, error) {
        if (value is! List) {
          return Text('Expected array of rows', style: theme.textTheme.bodyMedium);
        }
        final rows = value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .take(maxRows)
            .toList();
        if (rows.isEmpty) {
          return Text('No rows', style: theme.textTheme.bodyMedium);
        }
        if (columns.isEmpty) {
          final keys = rows.first.keys.toList();
          for (final k in keys) {
            columns.add((field: k, label: k));
          }
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            columns: [
              for (final c in columns)
                DataColumn(label: Text(c.label, style: theme.textTheme.labelLarge)),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    for (final c in columns)
                      DataCell(Text('${row[c.field] ?? ''}')),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
