import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/database_stats_repository.dart';

import '../../../curator/screen_program_curator.dart';
import '../../../theme/display_theme.dart';
import '../../dashboard_viewport_scope.dart';
import 'data_health_metrics.dart';

/// Operator-facing slide: SQLite content totals, category breakdowns, and charts.
class DataHealthSlideWidget extends StatefulWidget {
  const DataHealthSlideWidget({
    super.key,
    required this.db,
    required this.slide,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  State<DataHealthSlideWidget> createState() => _DataHealthSlideWidgetState();
}

class _DataHealthSlideWidgetState extends State<DataHealthSlideWidget> {
  static const List<String> _familyLabels = [
    'RSS',
    'Photos',
    'Videos',
    'Jokes',
    'Trivia',
  ];

  late final int _refreshSeconds;
  Timer? _timer;
  Future<DatabaseHealthSnapshot>? _future;

  @override
  void initState() {
    super.initState();
    _refreshSeconds = parseDataHealthRefreshSeconds(widget.spec.config);
    _reload();
    _timer = Timer.periodic(Duration(seconds: _refreshSeconds), (_) => _reload());
  }

  void _reload() {
    setState(() {
      _future = DatabaseStatsRepository(widget.db).load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    final palette = widget.theme.extension<PaletteTertiaryLayers>();
    final headline =
        widget.spec.config['headline'] as String? ?? 'Data health';
    final pad = EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s);

    return FutureBuilder<DatabaseHealthSnapshot>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Center(
            child: SizedBox(
              width: 48 * s,
              height: 48 * s,
              child: CircularProgressIndicator(
                strokeWidth: 3 * s,
                color: palette?.accent2 ?? widget.theme.colorScheme.primary,
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: pad,
              child: Text(
                'Could not load database statistics.',
                style: widget.theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final data = snap.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        return SingleChildScrollView(
          primary: false,
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                headline,
                style: widget.theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6 * s),
              Text(
                'Updated ${formatDataHealthTime(data.collectedAt)}',
                style: widget.theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16 * s),
              _summaryStrip(context, data, s),
              SizedBox(height: 20 * s),
              Text(
                'Active content by type',
                style: widget.theme.textTheme.titleMedium,
              ),
              SizedBox(height: 8 * s),
              SizedBox(
                height: 200 * s,
                child: _familyBarChart(data, s),
              ),
              SizedBox(height: 24 * s),
              Text(
                'Photos and videos by category',
                style: widget.theme.textTheme.titleMedium,
              ),
              SizedBox(height: 8 * s),
              SizedBox(
                height: 220 * s,
                child: _mediaByCategoryChart(data, s),
              ),
              SizedBox(height: 24 * s),
              Text(
                'RSS articles on screens',
                style: widget.theme.textTheme.titleMedium,
              ),
              SizedBox(height: 8 * s),
              Text(
                'With image ${data.rssArticlesWithImage} · '
                'Without image ${data.rssArticlesWithoutImage}',
                style: widget.theme.textTheme.bodyMedium,
              ),
              SizedBox(height: 12 * s),
              if (data.rssArticleTotal > 0)
                SizedBox(
                  height: 180 * s,
                  child: _rssSuppressedPie(data, s),
                )
              else
                Text(
                  'No RSS articles yet.',
                  style: widget.theme.textTheme.bodyMedium,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryStrip(
    BuildContext context,
    DatabaseHealthSnapshot d,
    double s,
  ) {
    final surface = widget.theme.colorScheme.surfaceContainerHighest;
    final chips = <Widget>[
      _statChip(
        surface,
        s,
        'Blob store',
        '${formatDataHealthBytes(d.blobTotalBytes)} · ${d.blobRowCount} files',
      ),
      _statChip(
        surface,
        s,
        'Feeds',
        '${d.rssFeedsEnabled} on · ${d.rssFeedsDisabled} off · '
        '${d.rssFeedsWithConsecutiveFailures} retrying',
      ),
      _statChip(
        surface,
        s,
        'Calendar',
        '${d.calendarEventCount} events',
      ),
    ];
    return Wrap(
      spacing: 10 * s,
      runSpacing: 10 * s,
      alignment: WrapAlignment.center,
      children: chips,
    );
  }

  Widget _statChip(Color surface, double s, String title, String value) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12 * s),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: widget.theme.textTheme.labelLarge),
            SizedBox(height: 4 * s),
            Text(value, style: widget.theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _familyBarChart(DatabaseHealthSnapshot d, double s) {
    final palette = widget.theme.extension<PaletteTertiaryLayers>();
    final colors = [
      palette?.accent1 ?? widget.theme.colorScheme.primary,
      palette?.accent2 ?? widget.theme.colorScheme.secondary,
      palette?.accent3 ?? widget.theme.colorScheme.tertiary,
      palette?.accent4 ?? widget.theme.colorScheme.primaryContainer,
      palette?.iconColor ?? widget.theme.colorScheme.outline,
    ];
    final values = [
      d.rssArticleActive.toDouble(),
      d.photoActive.toDouble(),
      d.videoActive.toDouble(),
      d.jokeActive.toDouble(),
      d.triviaActive.toDouble(),
    ];
    final maxY = values.fold<double>(0, (a, b) => a > b ? a : b);
    final top = maxY <= 0 ? 1.0 : maxY * 1.15;

    final groups = <BarChartGroupData>[
      for (var i = 0; i < _familyLabels.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: colors[i % colors.length],
              width: 18 * s,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6 * s),
                topRight: Radius.circular(6 * s),
              ),
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        maxY: top,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36 * s,
              interval: top <= 5 ? 1 : null,
              getTitlesWidget: (v, m) => Text(
                v == v.roundToDouble() ? v.toInt().toString() : '',
                style: widget.theme.textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28 * s,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= _familyLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: EdgeInsets.only(top: 4 * s),
                  child: Text(
                    _familyLabels[i],
                    style: widget.theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
        alignment: BarChartAlignment.spaceAround,
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  Widget _mediaByCategoryChart(DatabaseHealthSnapshot d, double s) {
    final merged = mergePhotosVideosForChart(d);
    if (merged.isEmpty) {
      return Center(
        child: Text(
          'No photos or videos yet.',
          style: widget.theme.textTheme.bodyMedium,
        ),
      );
    }

    final palette = widget.theme.extension<PaletteTertiaryLayers>();
    final photoColor =
        palette?.accent2 ?? widget.theme.colorScheme.secondary;
    final videoColor =
        palette?.accent3 ?? widget.theme.colorScheme.tertiary;

    final maxY = merged
        .map((e) => e.photos + e.videos)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();
    final top = maxY <= 0 ? 1.0 : maxY * 1.15;

    final groups = <BarChartGroupData>[
      for (var i = 0; i < merged.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 4 * s,
          barRods: [
            BarChartRodData(
              toY: merged[i].photos.toDouble(),
              color: photoColor,
              width: 10 * s,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4 * s),
                topRight: Radius.circular(4 * s),
              ),
            ),
            BarChartRodData(
              toY: merged[i].videos.toDouble(),
              color: videoColor,
              width: 10 * s,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4 * s),
                topRight: Radius.circular(4 * s),
              ),
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        maxY: top,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32 * s,
              interval: top <= 5 ? 1 : null,
              getTitlesWidget: (v, m) => Text(
                v == v.roundToDouble() ? v.toInt().toString() : '',
                style: widget.theme.textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40 * s,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= merged.length) {
                  return const SizedBox.shrink();
                }
                final label = merged[i].label;
                final short =
                    label.length > 10 ? '${label.substring(0, 9)}…' : label;
                return Padding(
                  padding: EdgeInsets.only(top: 4 * s),
                  child: Text(
                    short,
                    style: widget.theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
        alignment: BarChartAlignment.spaceAround,
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  Widget _rssSuppressedPie(DatabaseHealthSnapshot d, double s) {
    final palette = widget.theme.extension<PaletteTertiaryLayers>();
    final activeC =
        palette?.accent1 ?? widget.theme.colorScheme.primary;
    final hiddenC =
        palette?.accent4 ?? widget.theme.colorScheme.errorContainer;

    final active = d.rssArticleActive.toDouble();
    final hidden = d.rssArticleSuppressed.toDouble();

    if (active <= 0 && hidden <= 0) {
      return const SizedBox.shrink();
    }

    final sections = <PieChartSectionData>[];
    if (active > 0) {
      sections.add(
        PieChartSectionData(
          value: active,
          color: activeC,
          radius: 70 * s,
          title: 'Active\n${active.toInt()}',
          titleStyle: widget.theme.textTheme.bodySmall?.copyWith(
            color: widget.theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (hidden > 0) {
      sections.add(
        PieChartSectionData(
          value: hidden,
          color: hiddenC,
          radius: 70 * s,
          title: 'Hidden\n${hidden.toInt()}',
          titleStyle: widget.theme.textTheme.bodySmall?.copyWith(
            color: widget.theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 28 * s,
              sectionsSpace: 2,
            ),
            duration: const Duration(milliseconds: 200),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendRow(s, activeC, 'Active in rotation'),
              SizedBox(height: 8 * s),
              _legendRow(s, hiddenC, 'Suppressed / hidden'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(double s, Color c, String text) {
    return Row(
      children: [
        Container(
          width: 14 * s,
          height: 14 * s,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3 * s),
          ),
        ),
        SizedBox(width: 8 * s),
        Expanded(
          child: Text(text, style: widget.theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
