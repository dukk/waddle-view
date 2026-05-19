import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'kv_widget_base.dart';

class KvShapeSlideWidget extends StatelessWidget {
  const KvShapeSlideWidget({
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
    final shape = cfgString(spec.config, 'shape') ?? 'rectangle';
    final colorHex = cfgString(spec.config, 'color') ?? '#3366cc';
    final width = cfgDouble(spec.config, 'width') ?? 120;
    final height = cfgDouble(spec.config, 'height') ?? 80;

    return KvWidgetBase(
      db: db,
      spec: spec,
      theme: theme,
      builder: (context, value, error) {
        var resolvedShape = shape;
        var resolvedColor = _parseColor(colorHex);
        if (value is Map) {
          final s = value['shape'];
          final c = value['color'];
          if (s is String && s.isNotEmpty) {
            resolvedShape = s;
          }
          if (c is String && c.isNotEmpty) {
            resolvedColor = _parseColor(c);
          }
        }
        if (resolvedShape == 'circle') {
          return Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              color: resolvedColor,
              shape: BoxShape.circle,
            ),
          );
        }
        if (resolvedShape == 'line') {
          return Container(
            width: width,
            height: 4,
            color: resolvedColor,
          );
        }
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: resolvedColor,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      h = 'FF$h';
    }
    final value = int.tryParse(h, radix: 16);
    if (value == null) {
      return Colors.blue;
    }
    return Color(value);
  }
}
