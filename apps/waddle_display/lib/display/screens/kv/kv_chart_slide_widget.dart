import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'kv_widget_base.dart';

class KvChartSlideWidget extends StatelessWidget {
  const KvChartSlideWidget({
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
    final chartKind = cfgString(spec.config, 'chartKind') ?? 'line';
    final xField = cfgString(spec.config, 'xField') ?? 'x';
    final yField = cfgString(spec.config, 'yField') ?? 'y';

    return KvWidgetBase(
      db: db,
      spec: spec,
      theme: theme,
      builder: (context, value, error) {
        final points = _coercePoints(value, xField, yField);
        if (points.isEmpty) {
          return Text('No chart data', style: theme.textTheme.bodyMedium);
        }
        final maxY = points
            .map((p) => p.y)
            .fold<double>(0, (a, b) => a > b ? a : b);
        final barGroups = <BarChartGroupData>[];
        for (var i = 0; i < points.length; i++) {
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].y,
                  color: theme.colorScheme.primary,
                  width: 12,
                ),
              ],
            ),
          );
        }
        final spots = [
          for (var i = 0; i < points.length; i++)
            FlSpot(i.toDouble(), points[i].y),
        ];
        return SizedBox(
          height: 220,
          child: chartKind == 'bar'
              ? BarChart(
                  BarChartData(
                    maxY: maxY <= 0 ? 1 : maxY * 1.1,
                    barGroups: barGroups,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            final i = v.round();
                            if (i < 0 || i >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              points[i].x,
                              style: theme.textTheme.labelSmall,
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: true),
                  ),
                )
              : LineChart(
                  LineChartData(
                    maxY: maxY <= 0 ? 1 : maxY * 1.1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            final i = v.round();
                            if (i < 0 || i >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              points[i].x,
                              style: theme.textTheme.labelSmall,
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: true),
                  ),
                ),
        );
      },
    );
  }

  List<({String x, double y})> _coercePoints(
    dynamic value,
    String xField,
    String yField,
  ) {
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is Map && value['series'] is List) {
      list = value['series'] as List;
    } else {
      return const [];
    }
    final out = <({String x, double y})>[];
    for (final item in list) {
      if (item is! Map) {
        continue;
      }
      final x = item[xField];
      final y = item[yField];
      if (y is! num) {
        continue;
      }
      out.add((x: '$x', y: y.toDouble()));
    }
    return out;
  }
}
