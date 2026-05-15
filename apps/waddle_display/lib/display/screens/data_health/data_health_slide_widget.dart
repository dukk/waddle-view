import 'dart:async';
import 'dart:math' as math;

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
                height: 220 * s,
                child: _familyContentPie(data, s),
              ),
              SizedBox(height: 24 * s),
              Text(
                'Photos and videos by category',
                style: widget.theme.textTheme.titleMedium,
              ),
              SizedBox(height: 8 * s),
              SizedBox(
                height: 280 * s,
                child: _mediaByCategoryPies(data, s),
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

  List<Color> _familyTypeColors() {
    final palette = widget.theme.extension<PaletteTertiaryLayers>();
    return [
      palette?.accent1 ?? widget.theme.colorScheme.primary,
      palette?.accent2 ?? widget.theme.colorScheme.secondary,
      palette?.accent3 ?? widget.theme.colorScheme.tertiary,
      palette?.accent4 ?? widget.theme.colorScheme.primaryContainer,
      palette?.iconColor ?? widget.theme.colorScheme.outline,
    ];
  }

  /// Distinct colors for category wedges (reused for photos and videos pies).
  List<Color> _categoryColors(int n) {
    final palette = widget.theme.extension<PaletteTertiaryLayers>();
    final base = <Color>[
      palette?.accent2 ?? widget.theme.colorScheme.secondary,
      palette?.accent3 ?? widget.theme.colorScheme.tertiary,
      palette?.accent1 ?? widget.theme.colorScheme.primary,
      palette?.accent4 ?? widget.theme.colorScheme.primaryContainer,
      palette?.iconColor ?? widget.theme.colorScheme.outline,
      widget.theme.colorScheme.secondaryContainer,
      widget.theme.colorScheme.tertiaryContainer,
    ];
    return List<Color>.generate(
      n,
      (i) => base[i % base.length],
      growable: false,
    );
  }

  Widget _familyContentPie(DatabaseHealthSnapshot d, double s) {
    final colors = _familyTypeColors();
    final values = [
      d.rssArticleActive.toDouble(),
      d.photoActive.toDouble(),
      d.videoActive.toDouble(),
      d.jokeActive.toDouble(),
      d.triviaActive.toDouble(),
    ];
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return Center(
        child: Text(
          'No active content yet.',
          style: widget.theme.textTheme.bodyMedium,
        ),
      );
    }

    final sections = <PieChartSectionData>[
      for (var i = 0; i < _familyLabels.length; i++)
        if (values[i] > 0)
          PieChartSectionData(
            value: values[i],
            color: colors[i],
            radius: 58 * s,
            showTitle: false,
          ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 52,
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 20 * s,
                sectionsSpace: 2,
              ),
              duration: const Duration(milliseconds: 200),
            ),
          ),
        ),
        SizedBox(width: 12 * s),
        Expanded(
          flex: 48,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _familyLabels.length; i++)
                  if (values[i] > 0)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8 * s),
                      child: _legendRow(
                        s,
                        colors[i],
                        '${_familyLabels[i]} · ${values[i].toInt()}',
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mediaByCategoryPies(DatabaseHealthSnapshot d, double s) {
    final merged = mergePhotosVideosForChart(d);
    if (merged.isEmpty) {
      return Center(
        child: Text(
          'No photos or videos yet.',
          style: widget.theme.textTheme.bodyMedium,
        ),
      );
    }

    final colors = _categoryColors(merged.length);
    final photoSections = <PieChartSectionData>[
      for (var i = 0; i < merged.length; i++)
        if (merged[i].photos > 0)
          PieChartSectionData(
            value: merged[i].photos.toDouble(),
            color: colors[i],
            radius: 50 * s,
            showTitle: false,
          ),
    ];
    final videoSections = <PieChartSectionData>[
      for (var i = 0; i < merged.length; i++)
        if (merged[i].videos > 0)
          PieChartSectionData(
            value: merged[i].videos.toDouble(),
            color: colors[i],
            radius: 50 * s,
            showTitle: false,
          ),
    ];

    Widget pieCell(List<PieChartSectionData> sections, String emptyLabel) {
      if (sections.isEmpty) {
        return Center(
          child: Text(
            emptyLabel,
            style: widget.theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, c) {
          final side = math.min(c.maxWidth, c.maxHeight);
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 14 * s,
                  sectionsSpace: 2,
                ),
                duration: const Duration(milliseconds: 200),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Photos',
                      style: widget.theme.textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4 * s),
                    Expanded(
                      child: pieCell(photoSections, 'None'),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Videos',
                      style: widget.theme.textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4 * s),
                    Expanded(
                      child: pieCell(videoSections, 'None'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10 * s),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < merged.length; i++) ...[
                  if (i > 0) SizedBox(height: 6 * s),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2 * s),
                        child: Container(
                          width: 12 * s,
                          height: 12 * s,
                          decoration: BoxDecoration(
                            color: colors[i],
                            borderRadius: BorderRadius.circular(3 * s),
                          ),
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Expanded(
                        child: Text(
                          '${merged[i].label}\n'
                          '${merged[i].photos} photos · ${merged[i].videos} videos',
                          style: widget.theme.textTheme.bodySmall,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
