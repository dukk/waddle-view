import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../blob/blob_store.dart';
import '../debug/app_debug_log.dart';
import '../curator/curator_content_pools.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'analog_clock_slide_widget.dart';
import 'calendar_month_slide_widget.dart';
import 'dashboard_kv_flags.dart';
import 'dashboard_viewport_scope.dart';
import 'digital_clock_slide_widget.dart';
import 'admin_setup_slide_widget.dart';
import 'guest_wifi_slide_widget.dart';
import 'joke_slide_widget.dart';
import 'local_api_slide_widget.dart';
import 'pexels_photo_slide_widget.dart';
import 'pexels_video_slide_widget.dart';
import 'rss_article_columns_slide_widget.dart';
import 'rss_article_slide_widget.dart';
import 'rss_article_stack_slide_widget.dart';
import 'trivia_slide_widget.dart';
import 'weather_slide_widget.dart';

String screenShownDebugLogLine({
  required String reason,
  required int slideIndex,
  required int totalSlides,
  required String screenId,
  required int dwellMs,
  required String layoutJson,
  required Map<String, String> randomChoices,
}) {
  return 'screen shown: reason=$reason index=$slideIndex/$totalSlides '
      'screenId=$screenId dwellMs=$dwellMs '
      'layout=$layoutJson randomChoices=$randomChoices';
}

/// Full-area carousel above the ticker: slides exit left / enter right between
/// curated programs loaded from `screen_definitions` and [config_key_values].
class ScreenRotator extends StatefulWidget {
  const ScreenRotator({
    super.key,
    required this.db,
    required this.blobs,
    required this.localRestBaseUrl,
    required this.adminBaseUrl,
    required this.setupPasswordFile,
  });

  final AppDatabase db;
  final BlobStore blobs;

  /// Bound loopback base URL for the in-process REST server (e.g. `http://127.0.0.1:8787`).
  final String localRestBaseUrl;
  final String adminBaseUrl;
  final File setupPasswordFile;

  @override
  State<ScreenRotator> createState() => _ScreenRotatorState();
}

class _ScreenRotatorState extends State<ScreenRotator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeInOutCubic,
  );

  final _random = Random();
  final List<String> _recentScreenIds = [];

  List<ResolvedSlide> _program = const [];
  int _index = 0;
  ResolvedSlide? _fromSlide;
  ResolvedSlide? _toSlide;
  Timer? _dwellTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _startNewProgram();
  }

  Future<void> _startNewProgram() async {
    final defs =
        await (widget.db.select(widget.db.screenDefinitions)
              ..where((t) => t.enabled.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    final kvRows = await widget.db.select(widget.db.configKeyValues).get();
    final kvByKey = {for (final row in kvRows) row.key: row.value};
    final programSeconds =
        int.tryParse(
          kvByKey[kCuratorProgramDurationSecondsKvKey]?.trim() ?? '',
        ) ??
        180;
    final programMs = programSeconds * 1000;
    final historyDepth =
        int.tryParse(kvByKey[kCuratorHistoryDepthKvKey]?.trim() ?? '') ?? 5;
    final requireNewsPhotoForScreens = isTruthyDashboardKvFlag(
      kvByKey[kRequireNewsPhotoForScreensKvKey],
      defaultValue: true,
    );

    final blobs = await widget.db.select(widget.db.blobMetadata).get();
    final loadedPools = await loadCuratorContentPools(widget.db);
    final pools = <String, List<String>>{
      ...loadedPools.pools,
      if (blobs.isNotEmpty) 'blobs': blobs.map((e) => e.blobKey).toList(),
    };
    final dataKeyLimitRows = await widget.db
        .select(widget.db.curatorDataKeyProgramLimits)
        .get();
    final dataKeyLimits = <String, DataKeyProgramLimit>{};
    for (final row in dataKeyLimitRows) {
      dataKeyLimits[row.dataKey] = DataKeyProgramLimit(
        minPlacementsPerProgram: row.minPlacementsPerProgram,
        maxPlacementsPerProgram: row.maxPlacementsPerProgram,
      );
    }

    final candidates = defs
        .map(
          (r) => ScreenCandidate(
            id: r.id,
            dwellMs: r.dwellSeconds * 1000,
            frequencyWeight: r.frequencyWeight,
            minGapBetweenShowsMs: r.minGapBetweenShowsSeconds * 1000,
            minPlacementsPerProgram: r.minPlacementsPerProgram,
            maxPlacementsPerProgram: r.maxPlacementsPerProgram,
            dataKey: r.dataKey,
            layoutJson: r.layoutJson,
            enabled: r.enabled,
          ),
        )
        .toList();

    final program = ScreenProgramCurator.buildProgram(
      screens: candidates,
      programDurationMs: programMs,
      recentScreenIdsOldestFirst: List<String>.from(_recentScreenIds),
      historyDepth: historyDepth,
      random: _random,
      randomPools: pools,
      dataKeyLimits: dataKeyLimits,
      rssArticleMetrics: loadedPools.rssArticleMetrics,
      requirePhotoForRssScreens: requireNewsPhotoForScreens,
    );

    if (kDebugMode) {
      for (final line in ScreenProgramCurator.curatedProgramDebugLogLines(
        program: program,
        programDurationMs: programMs,
        historyDepth: historyDepth,
        recentScreenIdsOldestFirst: List<String>.from(_recentScreenIds),
      )) {
        AppDebugLog.screen(line);
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _program = program;
      _index = 0;
      _fromSlide = null;
      _toSlide = program.isEmpty ? null : program.first;
    });
    final firstSlide = program.isEmpty ? null : program.first;
    if (firstSlide != null) {
      AppDebugLog.screen(
        screenShownDebugLogLine(
          reason: 'program_start',
          slideIndex: 0,
          totalSlides: program.length,
          screenId: firstSlide.screenId,
          dwellMs: firstSlide.dwellMs,
          layoutJson: firstSlide.layoutJson,
          randomChoices: firstSlide.randomChoices,
        ),
      );
    }
    _scheduleDwellForCurrentSlide();
  }

  void _scheduleDwellForCurrentSlide() {
    _dwellTimer?.cancel();
    if (_program.isEmpty || _toSlide == null) {
      return;
    }
    final slide = _program[_index];
    _dwellTimer = Timer(Duration(milliseconds: slide.dwellMs), _onDwellElapsed);
  }

  void _reportDesiredDwellForSlide(int slideIndex, int ms) {
    if (!mounted || _program.isEmpty || slideIndex != _index) {
      return;
    }
    if (ms <= 0) {
      return;
    }
    _dwellTimer?.cancel();
    _dwellTimer = Timer(Duration(milliseconds: ms), _onDwellElapsed);
  }

  Future<void> _onDwellElapsed() async {
    if (!mounted || _program.isEmpty) {
      return;
    }
    final slide = _program[_index];
    _recentScreenIds.add(slide.screenId);
    while (_recentScreenIds.length > 200) {
      _recentScreenIds.removeAt(0);
    }

    final nextIndex = _index + 1;
    if (nextIndex >= _program.length) {
      await _startNewProgram();
      return;
    }

    final next = _program[nextIndex];
    setState(() {
      _fromSlide = slide;
      _toSlide = next;
      _index = nextIndex;
    });
    AppDebugLog.screen(
      screenShownDebugLogLine(
        reason: 'transition',
        slideIndex: nextIndex,
        totalSlides: _program.length,
        screenId: next.screenId,
        dwellMs: next.dwellMs,
        layoutJson: next.layoutJson,
        randomChoices: next.randomChoices,
      ),
    );
    _anim.forward(from: 0).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fromSlide = null;
      });
      _scheduleDwellForCurrentSlide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outgoing = _fromSlide;
    final incoming = _toSlide ?? outgoing;

    if (_program.isEmpty) {
      return Center(
        child: Text(
          'No display screens enabled',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (outgoing != null && incoming != null && outgoing != incoming)
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-1, 0),
              ).animate(_curve),
              child: _SlideContent(
                db: widget.db,
                blobs: widget.blobs,
                localRestBaseUrl: widget.localRestBaseUrl,
                adminBaseUrl: widget.adminBaseUrl,
                setupPasswordFile: widget.setupPasswordFile,
                slide: outgoing,
                theme: theme,
                slideIndex: _index > 0 ? _index - 1 : 0,
                onReportDesiredDwell: _reportDesiredDwellForSlide,
              ),
            ),
          SlideTransition(
            position: Tween<Offset>(
              begin: outgoing != null && outgoing != incoming
                  ? const Offset(1, 0)
                  : Offset.zero,
              end: Offset.zero,
            ).animate(_curve),
            child: incoming != null
                ? _SlideContent(
                    db: widget.db,
                    blobs: widget.blobs,
                    localRestBaseUrl: widget.localRestBaseUrl,
                    adminBaseUrl: widget.adminBaseUrl,
                    setupPasswordFile: widget.setupPasswordFile,
                    slide: incoming,
                    theme: theme,
                    slideIndex: _index,
                    onReportDesiredDwell: _reportDesiredDwellForSlide,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({
    required this.db,
    required this.blobs,
    required this.localRestBaseUrl,
    required this.adminBaseUrl,
    required this.setupPasswordFile,
    required this.slide,
    required this.theme,
    required this.slideIndex,
    required this.onReportDesiredDwell,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final String localRestBaseUrl;
  final String adminBaseUrl;
  final File setupPasswordFile;
  final ResolvedSlide slide;
  final ThemeData theme;
  final int slideIndex;
  final void Function(int slideIndex, int ms) onReportDesiredDwell;

  @override
  Widget build(BuildContext context) {
    final widgets = parseScreenLayoutWidgets(slide.layoutJson);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: EdgeInsets.zero,
      child: Center(
        child: _buildWidgets(
          context,
          widgets,
          slide,
          slideIndex,
          onReportDesiredDwell,
        ),
      ),
    );
  }

  Widget _buildWidgets(
    BuildContext context,
    List<ParsedWidgetSpec> widgets,
    ResolvedSlide slide,
    int slideIndex,
    void Function(int slideIndex, int ms) onReportDesiredDwell,
  ) {
    final s = DashboardViewportScope.scaleOf(context);
    final gap = 12.0 * s;
    if (widgets.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Text(
          'Empty layout',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }
    // Single full-bleed widgets (like rss_article) need bounded size
    // constraints; putting them in an intrinsic-height Column can pass
    // unbounded height and cause them to render empty.
    if (widgets.length == 1 && widgets.first.type == 'rss_article') {
      final w = widgets.first;
      return SizedBox.expand(
        child: RssArticleSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
          onReportDesiredDwell: (ms) => onReportDesiredDwell(slideIndex, ms),
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'rss_article_columns') {
      final w = widgets.first;
      return SizedBox.expand(
        child: RssArticleColumnsSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
          onReportDesiredDwell: (ms) => onReportDesiredDwell(slideIndex, ms),
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'rss_article_stack') {
      final w = widgets.first;
      return SizedBox.expand(
        child: RssArticleStackSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
          onReportDesiredDwell: (ms) => onReportDesiredDwell(slideIndex, ms),
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'pexels_photo') {
      final w = widgets.first;
      return SizedBox.expand(
        child: PexelsPhotoSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'pexels_video') {
      final w = widgets.first;
      return SizedBox.expand(
        child: PexelsVideoSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
        ),
      );
    }
    // Multi-widget stacks can exceed the slide viewport (e.g. two tall tiles).
    // Scroll instead of overflowing; bounded height comes from the rotator area.
    return SingleChildScrollView(
      primary: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: widgets.map((w) {
          switch (w.type) {
            case 'static_text':
              final text = w.config['text'] as String? ?? '';
              return Padding(
                padding: EdgeInsets.only(bottom: gap),
                child: Text(
                  text,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              );
            case 'joke':
              return JokeSlideWidget(
                db: db,
                slide: slide,
                spec: w,
                theme: theme,
              );
            case 'trivia':
              return TriviaSlideWidget(
                db: db,
                slide: slide,
                spec: w,
                theme: theme,
              );
            case 'guest_wifi':
              return GuestWifiSlideWidget(db: db, spec: w, theme: theme);
            case 'digital_clock':
              return DigitalClockSlideWidget(spec: w, theme: theme);
            case 'analog_clock':
              return AnalogClockSlideWidget(spec: w, theme: theme);
            case 'calendar_month':
              return CalendarMonthSlideWidget(db: db, spec: w, theme: theme);
            case 'photo_random':
              final key = slide.randomChoices[w.choiceKey];
              return Padding(
                padding: EdgeInsets.only(bottom: gap),
                child: Text(
                  key != null ? 'Photo: $key' : 'No photo in pool',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              );
            case 'rss_article':
              return RssArticleSlideWidget(
                db: db,
                blobs: blobs,
                slide: slide,
                spec: w,
                theme: theme,
                onReportDesiredDwell: (ms) =>
                    onReportDesiredDwell(slideIndex, ms),
              );
            case 'rss_article_columns':
              return RssArticleColumnsSlideWidget(
                db: db,
                blobs: blobs,
                slide: slide,
                spec: w,
                theme: theme,
                onReportDesiredDwell: (ms) =>
                    onReportDesiredDwell(slideIndex, ms),
              );
            case 'rss_article_stack':
              return RssArticleStackSlideWidget(
                db: db,
                blobs: blobs,
                slide: slide,
                spec: w,
                theme: theme,
                onReportDesiredDwell: (ms) =>
                    onReportDesiredDwell(slideIndex, ms),
              );
            case 'local_api':
              return LocalApiSlideWidget(
                baseUrl: localRestBaseUrl,
                spec: w,
                theme: theme,
              );
            case 'admin_setup':
              return AdminSetupSlideWidget(
                db: db,
                adminBaseUrl: adminBaseUrl,
                setupPasswordFile: setupPasswordFile,
                spec: w,
                theme: theme,
              );
            case 'weather':
              return WeatherSlideWidget(
                db: db,
                slide: slide,
                spec: w,
                theme: theme,
              );
            case 'pexels_photo':
              return PexelsPhotoSlideWidget(
                db: db,
                blobs: blobs,
                slide: slide,
                spec: w,
                theme: theme,
              );
            case 'pexels_video':
              return PexelsVideoSlideWidget(
                db: db,
                blobs: blobs,
                slide: slide,
                spec: w,
                theme: theme,
              );
            default:
              return Padding(
                padding: EdgeInsets.only(bottom: gap),
                child: Text(
                  'Unknown widget: ${w.type}',
                  style: theme.textTheme.bodyMedium,
                ),
              );
          }
        }).toList(),
      ),
    );
  }
}
