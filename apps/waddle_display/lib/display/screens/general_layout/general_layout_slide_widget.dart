import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/kv_schema_documentation.dart';

import '../../../extensions/screen_widget_registry.dart';
import '../../dashboard_viewport_scope.dart';
/// Multi-slot grid for `general_*` screen types.
class GeneralLayoutSlideWidget extends StatelessWidget {
  const GeneralLayoutSlideWidget({
    super.key,
    required this.layoutType,
    required this.widgets,
    required this.buildCtx,
    required this.theme,
  });

  final String layoutType;
  final List<ParsedWidgetSpec> widgets;
  final ScreenWidgetBuildContext buildCtx;
  final ThemeData theme;

  static String? layoutTypeFromJson(String layoutJson) {
    try {
      final decoded = jsonDecode(layoutJson);
      if (decoded is Map<String, dynamic>) {
        final layout = decoded['layout'];
        if (layout is String && isGeneralLayoutScreenType(layout)) {
          return layout;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    final gap = 8.0 * s;
    final bySlot = {for (final w in widgets) w.slot: w};
    final rows = _rowsForLayout(layoutType);

    return Padding(
      padding: EdgeInsets.all(12 * s),
      child: Column(
        children: [
          for (var ri = 0; ri < rows.length; ri++) ...[
            if (ri > 0) SizedBox(height: gap),
            Expanded(
              child: Row(
                children: [
                  for (var ci = 0; ci < rows[ri].length; ci++) ...[
                    if (ci > 0) SizedBox(width: gap),
                    Expanded(
                      child: _cell(context, bySlot[rows[ri][ci]]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, ParsedWidgetSpec? spec) {
    if (spec == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text('Empty slot', style: theme.textTheme.bodySmall),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: SingleChildScrollView(
            child: const ScreenWidgetRegistry().buildInColumn(
              buildCtx,
              spec,
            ),
          ),
        ),
      ),
    );
  }

  List<List<String>> _rowsForLayout(String type) {
    switch (type) {
      case 'general_full_screen':
        return const [
          ['main'],
        ];
      case 'general_2_column':
        return const [
          ['left', 'right'],
        ];
      case 'general_3_column':
        return const [
          ['left', 'center', 'right'],
        ];
      case 'general_2x2':
        return const [
          ['a1', 'a2'],
          ['b1', 'b2'],
        ];
      case 'general_3x2':
        return const [
          ['a1', 'a2', 'a3'],
          ['b1', 'b2', 'b3'],
        ];
      default:
        final slots = generalLayoutSlotIdsForScreenType(type);
        if (slots.isEmpty) {
          return const [
            ['main'],
          ];
        }
        return [slots];
    }
  }
}
