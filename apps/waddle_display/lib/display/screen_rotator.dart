import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import '../debug/app_debug_log.dart';
import '../debug/operator_telemetry_hub.dart';
import '../curator/curator_content_pools.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../curator/active_curator_service.dart';
import '../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../theme/display_theme.dart';
import 'dashboard_viewport_scope.dart';
import 'display_navigation_bus.dart';
import 'viewer_invite_runtime.dart';
import 'slide_content_preload.dart';
import 'screens/controller_invite/controller_invite_slide_widget.dart';
import 'screens/data_health/data_health_slide_widget.dart';
import 'screens/photo/photo_collage_slide_widget.dart';
import 'screens/photo/photo_slide_widget.dart';
import 'screens/photo/video_slide_widget.dart';
import 'screens/news/news_columns_slide_widget.dart';
import 'screens/news/news_slide_widget.dart';
import 'screens/news/news_stack_slide_widget.dart';
import 'screens/web_page/web_page_slide_widget.dart';
import '../extensions/screen_widget_registry.dart';

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
/// curated programs loaded from `screens` and [config_key_values].
class ScreenRotator extends StatefulWidget {
  const ScreenRotator({
    super.key,
    required this.db,
    required this.blobs,
    required this.localRestBaseUrl,
    required this.adminBaseUrl,
    required this.instanceIdFile,
    required this.viewerInviteRuntime,
    this.telemetryHub,
    this.navigationBus,
  });

  final AppDatabase db;
  final BlobStore blobs;

  /// Bound base URL for the in-process REST server (e.g. `https://192.168.1.10:8787`).
  final String localRestBaseUrl;
  final String adminBaseUrl;
  final File instanceIdFile;

  /// Join QR / registration secret wiring from the display process environment.
  final ViewerInviteRuntime viewerInviteRuntime;

  /// Optional operator REST telemetry (in-memory ring buffer).
  final OperatorTelemetryHub? telemetryHub;

  /// Optional REST-driven navigation (same as arrow left/right on carousel).
  final DisplayNavigationBus? navigationBus;

  @override
  State<ScreenRotator> createState() => _ScreenRotatorState();
}

class _ScreenRotatorState extends State<ScreenRotator>
    with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeInOutCubic,
  );

  final _random = Random();
  late final ActiveCuratorService _curatorService;
  final List<String> _recentScreenIds = [];
  final Map<String, int> _lastShownAtMsByScreenId = {};
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'screen-rotator');

  final List<_ProgramHistoryEntry> _history = <_ProgramHistoryEntry>[];
  int _historyCursor = 0;
  int _slideCursor = 0;
  int _historyDepth = 5;
  int _slideTransitionDirection = 1;
  ResolvedSlide? _fromSlide;
  ResolvedSlide? _toSlide;
  Timer? _dwellTimer;
  Timer? _manualIdleTimer;
  String? _overlayNotice;
  int _overlayTimelineDirection = 1;
  bool _manualNavigationActive = false;
  late final AnimationController _overlayFadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 0,
  );
  late final Animation<double> _overlayFade = CurvedAnimation(
    parent: _overlayFadeController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Prepared slide loads keyed by `'${_historyCursor}_$slideIndex'`.
  final Map<String, Future<void>> _slidePrepareFutures = {};

  static const Duration _manualIdleTimeout = Duration(seconds: 3);

  String _slidePrepareKey(int slideIndex) => '${_historyCursor}_$slideIndex';

  void _invalidateSlidePrepareCache() {
    _slidePrepareFutures.clear();
  }

  Future<void> _prepareSlide(int index) async {
    if (_visibleProgram.isEmpty ||
        index < 0 ||
        index >= _visibleProgram.length) {
      return;
    }
    final key = _slidePrepareKey(index);
    final existing = _slidePrepareFutures[key];
    if (existing != null) {
      await existing;
      return;
    }
    final slide = _visibleProgram[index];
    final f = preloadResolvedSlideContent(
      db: widget.db,
      blobs: widget.blobs,
      slide: slide,
    );
    _slidePrepareFutures[key] = f;
    await f;
  }

  void _kickPrefetchNext() {
    final next = _slideCursor + 1;
    if (_visibleProgram.isEmpty || next >= _visibleProgram.length) {
      return;
    }
    final key = _slidePrepareKey(next);
    if (_slidePrepareFutures.containsKey(key)) {
      return;
    }
    final slide = _visibleProgram[next];
    _slidePrepareFutures[key] = preloadResolvedSlideContent(
      db: widget.db,
      blobs: widget.blobs,
      slide: slide,
    );
  }

  @override
  void initState() {
    super.initState();
    _curatorService = ActiveCuratorService(db: widget.db);
    widget.navigationBus?.addListener(_onExternalScreenNavigation);
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(covariant ScreenRotator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationBus != widget.navigationBus) {
      oldWidget.navigationBus?.removeListener(_onExternalScreenNavigation);
      widget.navigationBus?.addListener(_onExternalScreenNavigation);
    }
  }

  @override
  void dispose() {
    widget.navigationBus?.removeListener(_onExternalScreenNavigation);
    _dwellTimer?.cancel();
    _manualIdleTimer?.cancel();
    _anim.dispose();
    _overlayFadeController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _startNewProgram();
  }

  Future<void> _startNewProgram() async {
    final selection = await _curatorService.resolveAt(DateTime.now());
    final primary = selection.primary.configuration;
    final allowedScreenIds = primary.screenMemberIds;

    if (allowedScreenIds.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _history.clear();
        _history.add(const _ProgramHistoryEntry(slides: []));
        _historyCursor = 0;
        _slideCursor = 0;
      });
      return;
    }

    final defs =
        await (widget.db.select(widget.db.screens)
              ..where((t) => t.id.isIn(allowedScreenIds))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    final programMs = primary.programDurationSeconds * 1000;
    final historyDepth = primary.historyDepth;
    _historyDepth = historyDepth;
    final requireNewsPhotoForScreens = primary.requireNewsPhotoForScreens;

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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final candidates = defs
        .map(
          (r) => ScreenCandidate(
            id: r.id,
            minDwellMs: r.minDwellSeconds * 1000,
            maxDwellMs: r.maxDwellSeconds * 1000,
            frequencyWeight: r.frequencyWeight,
            minGapBetweenShowsMs: r.minGapBetweenShowsSeconds * 1000,
            minPlacementsPerProgram: r.minPlacementsPerProgram,
            maxPlacementsPerProgram: r.maxPlacementsPerProgram,
            dataKey: r.dataKey,
            layoutJson: synthesizeLayoutJson(
              screenType: r.screenType,
              configJson: r.configJson,
            ),
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
      photoMetrics: loadedPools.photoMetrics,
      requirePhotoForRssScreens: requireNewsPhotoForScreens,
      lastShownAtMsByScreenId: _lastShownAtMsByScreenId,
      nowMs: nowMs,
    );

    final screenTypeById = {for (final r in defs) r.id: r.screenType};
    widget.telemetryHub?.recordScreenProgram(
      reason: 'new_program',
      slides: program,
      screenTypeById: screenTypeById,
    );

    if (kDebugMode) {
      final dwellOk =
          candidates.where((c) => c.minDwellMs > 0 && c.maxDwellMs > 0).length;
      AppDebugLog.screen(
        'screen program: build context screenRows=${defs.length} dwellEligible=$dwellOk '
        'budgetMs=$programMs historyDepth=$historyDepth dataKeyLimits=${dataKeyLimits.length} '
        'randomPoolKeys=${pools.length} rssArticleMetrics=${loadedPools.rssArticleMetrics.length} '
        'photoMetrics=${loadedPools.photoMetrics.length} requireNewsPhoto=$requireNewsPhotoForScreens',
      );
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
    _invalidateSlidePrepareCache();
    final shouldResetView = !_manualNavigationActive || _historyCursor == 0;
    if (program.isNotEmpty && shouldResetView) {
      await preloadResolvedSlideContent(
        db: widget.db,
        blobs: widget.blobs,
        slide: program.first,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _history.insert(0, _ProgramHistoryEntry(slides: program));
      while (_history.length > _historyDepth) {
        _history.removeLast();
      }
      if (!_manualNavigationActive || _historyCursor == 0) {
        _historyCursor = 0;
        _slideCursor = 0;
        _fromSlide = null;
        _toSlide = program.isEmpty ? null : program.first;
      }
    });
    if (shouldResetView && program.isNotEmpty) {
      _slidePrepareFutures[_slidePrepareKey(0)] = Future.value();
    }
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

  List<ResolvedSlide> get _visibleProgram =>
      _history.isEmpty ? const [] : _history[_historyCursor].slides;

  bool get _canAutoAdvance =>
      !_manualNavigationActive &&
      _historyCursor == 0 &&
      _visibleProgram.isNotEmpty;

  void _scheduleDwellForCurrentSlide() {
    _dwellTimer?.cancel();
    if (!_canAutoAdvance || _toSlide == null) {
      _kickPrefetchNext();
      return;
    }
    final slide = _visibleProgram[_slideCursor];
    _dwellTimer = Timer(Duration(milliseconds: slide.dwellMs), _onDwellElapsed);
    _kickPrefetchNext();
  }

  void _reportDesiredDwellForSlide(int slideIndex, int ms) {
    if (!mounted || !_canAutoAdvance || slideIndex != _slideCursor) {
      return;
    }
    if (ms <= 0) {
      return;
    }
    _dwellTimer?.cancel();
    _dwellTimer = Timer(Duration(milliseconds: ms), _onDwellElapsed);
  }

  Future<void> _onDwellElapsed() async {
    if (!mounted || !_canAutoAdvance) {
      return;
    }
    final slide = _visibleProgram[_slideCursor];
    _recentScreenIds.add(slide.screenId);
    _lastShownAtMsByScreenId[slide.screenId] =
        DateTime.now().millisecondsSinceEpoch;
    while (_recentScreenIds.length > 200) {
      _recentScreenIds.removeAt(0);
    }

    final nextIndex = _slideCursor + 1;
    if (nextIndex >= _visibleProgram.length) {
      await _startNewProgram();
      return;
    }

    final next = _visibleProgram[nextIndex];
    await _setVisibleSlide(nextIndex, animated: true, transitionDirection: 1);
    if (!mounted) {
      return;
    }
    AppDebugLog.screen(
      screenShownDebugLogLine(
        reason: 'transition',
        slideIndex: nextIndex,
        totalSlides: _visibleProgram.length,
        screenId: next.screenId,
        dwellMs: next.dwellMs,
        layoutJson: next.layoutJson,
        randomChoices: next.randomChoices,
      ),
    );
  }

  Future<void> _setVisibleSlide(
    int newIndex, {
    required bool animated,
    required int transitionDirection,
  }) async {
    if (_visibleProgram.isEmpty) {
      return;
    }
    final clampedIndex = newIndex.clamp(0, _visibleProgram.length - 1);
    await _prepareSlide(clampedIndex);
    if (!mounted) {
      return;
    }
    final current = _toSlide ?? _visibleProgram[_slideCursor];
    final next = _visibleProgram[clampedIndex];
    if (!animated) {
      setState(() {
        _slideCursor = clampedIndex;
        _slideTransitionDirection = transitionDirection;
        _fromSlide = null;
        _toSlide = next;
      });
      _scheduleDwellForCurrentSlide();
      return;
    }
    setState(() {
      _slideCursor = clampedIndex;
      _slideTransitionDirection = transitionDirection;
      _fromSlide = current;
      _toSlide = next;
    });
    await _anim.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _fromSlide = null;
    });
    _scheduleDwellForCurrentSlide();
  }

  void _showOverlay({String? notice}) {
    _overlayNotice = notice;
    _overlayFadeController.forward();
    _manualIdleTimer?.cancel();
    _manualIdleTimer = Timer(_manualIdleTimeout, _onManualIdleTimeout);
  }

  void _onManualIdleTimeout() {
    if (!mounted) {
      return;
    }
    setState(() {
      _manualNavigationActive = false;
      _overlayNotice = null;
    });
    _overlayFadeController.reverse();
    _scheduleDwellForCurrentSlide();
  }

  void _onExternalScreenNavigation() {
    if (!mounted) {
      return;
    }
    final dir = widget.navigationBus?.dequeueScreenNav();
    if (dir == null) {
      return;
    }
    if (dir < 0) {
      unawaited(_handleLeftNavigation());
    } else {
      unawaited(_handleRightNavigation());
    }
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || _history.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      unawaited(_handleLeftNavigation());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      unawaited(_handleRightNavigation());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _beginManualNavigation() {
    _dwellTimer?.cancel();
    _manualNavigationActive = true;
    _showOverlay();
  }

  Future<void> _handleLeftNavigation() async {
    _beginManualNavigation();
    if (_slideCursor > 0) {
      setState(() {
        _overlayNotice = null;
      });
      await _setVisibleSlide(
        _slideCursor - 1,
        animated: true,
        transitionDirection: -1,
      );
      return;
    }
    final olderProgramIndex = _historyCursor + 1;
    if (olderProgramIndex < _history.length) {
      final slides = _history[olderProgramIndex].slides;
      if (slides.isEmpty) {
        return;
      }
      final targetIdx = slides.length - 1;
      _invalidateSlidePrepareCache();
      await preloadResolvedSlideContent(
        db: widget.db,
        blobs: widget.blobs,
        slide: slides[targetIdx],
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _overlayNotice = null;
        _historyCursor = olderProgramIndex;
        _slideCursor = targetIdx;
        _slideTransitionDirection = -1;
        _overlayTimelineDirection = 1;
        _fromSlide = null;
        _toSlide = _visibleProgram[_slideCursor];
      });
      _slidePrepareFutures[_slidePrepareKey(targetIdx)] = Future.value();
      _kickPrefetchNext();
      return;
    }
    setState(() {
      _overlayNotice = 'You have reached the end of history.';
    });
  }

  Future<void> _handleRightNavigation() async {
    _beginManualNavigation();
    if (_slideCursor < _visibleProgram.length - 1) {
      setState(() {
        _overlayNotice = null;
      });
      await _setVisibleSlide(
        _slideCursor + 1,
        animated: true,
        transitionDirection: 1,
      );
      return;
    }
    if (_historyCursor > 0) {
      final newer = _historyCursor - 1;
      final slides = _history[newer].slides;
      if (slides.isEmpty) {
        return;
      }
      _invalidateSlidePrepareCache();
      await preloadResolvedSlideContent(
        db: widget.db,
        blobs: widget.blobs,
        slide: slides.first,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _historyCursor = newer;
        _slideCursor = 0;
        _slideTransitionDirection = 1;
        _overlayNotice = null;
        _overlayTimelineDirection = -1;
        _fromSlide = null;
        _toSlide = _visibleProgram.first;
      });
      _slidePrepareFutures[_slidePrepareKey(0)] = Future.value();
      _kickPrefetchNext();
      return;
    }
    setState(() {
      _overlayNotice = 'End of current program. Waiting for a new program.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outgoing = _fromSlide;
    final incoming = _toSlide ?? outgoing;
    final slideTransitionActive =
        outgoing != null && incoming != null && outgoing != incoming;

    if (_history.isEmpty || _visibleProgram.isEmpty) {
      return Center(
        child: Text(
          'No display screens enabled',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Focus(
      autofocus: true,
      focusNode: _keyboardFocusNode,
      onKeyEvent: _onKeyEvent,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (outgoing != null && incoming != null && outgoing != incoming)
              SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(-_slideTransitionDirection.toDouble(), 0),
                ).animate(_curve),
                child: _SlideContent(
                  db: widget.db,
                  blobs: widget.blobs,
                  localRestBaseUrl: widget.localRestBaseUrl,
                  adminBaseUrl: widget.adminBaseUrl,
                  instanceIdFile: widget.instanceIdFile,
                  viewerInviteRuntime: widget.viewerInviteRuntime,
                  slide: outgoing,
                  theme: theme,
                  slideIndex: _slideCursor > 0 ? _slideCursor - 1 : 0,
                  allowVideoPlayback: !slideTransitionActive,
                  onReportDesiredDwell: _reportDesiredDwellForSlide,
                ),
              ),
            SlideTransition(
              position: Tween<Offset>(
                begin: outgoing != null && outgoing != incoming
                    ? Offset(_slideTransitionDirection.toDouble(), 0)
                    : Offset.zero,
                end: Offset.zero,
              ).animate(_curve),
              child: incoming != null
                  ? _SlideContent(
                      db: widget.db,
                      blobs: widget.blobs,
                      localRestBaseUrl: widget.localRestBaseUrl,
                      adminBaseUrl: widget.adminBaseUrl,
                      instanceIdFile: widget.instanceIdFile,
                      viewerInviteRuntime: widget.viewerInviteRuntime,
                      slide: incoming,
                      theme: theme,
                      slideIndex: _slideCursor,
                      allowVideoPlayback: !slideTransitionActive,
                      onReportDesiredDwell: _reportDesiredDwellForSlide,
                    )
                  : const SizedBox.shrink(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: FadeTransition(
                opacity: _overlayFade,
                child: _overlayFadeController.value == 0
                    ? const SizedBox.shrink()
                    : _ScreenNavigationOverlay(
                        key: const Key('screen_nav_overlay_root'),
                        timelineKey: ValueKey<int>(_historyCursor),
                        timelineDirection: _overlayTimelineDirection,
                        slides: _visibleProgram,
                        currentIndex: _slideCursor,
                        notice: _overlayNotice,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramHistoryEntry {
  const _ProgramHistoryEntry({required this.slides});

  final List<ResolvedSlide> slides;
}

class _ScreenNavigationOverlay extends StatelessWidget {
  const _ScreenNavigationOverlay({
    super.key,
    required this.timelineKey,
    required this.timelineDirection,
    required this.slides,
    required this.currentIndex,
    required this.notice,
  });

  final Key timelineKey;
  final int timelineDirection;
  final List<ResolvedSlide> slides;
  final int currentIndex;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) {
            final begin = Offset(0, timelineDirection > 0 ? -0.35 : 0.35);
            return SlideTransition(
              position: Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: DecoratedBox(
            key: timelineKey,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    key: Key('screen_nav_overlay_timeline'),
                    height: 0,
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < slides.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i == currentIndex
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Text(
                                  slides[i].screenId,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: i == currentIndex
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current: ${slides[currentIndex].screenId}',
                    key: const Key('screen_nav_current_index'),
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            key: notice == 'You have reached the end of history.'
                ? const Key('screen_nav_end_history_message')
                : null,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(notice!, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ],
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({
    required this.db,
    required this.blobs,
    required this.localRestBaseUrl,
    required this.adminBaseUrl,
    required this.instanceIdFile,
    required this.viewerInviteRuntime,
    required this.slide,
    required this.theme,
    required this.slideIndex,
    required this.allowVideoPlayback,
    required this.onReportDesiredDwell,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final String localRestBaseUrl;
  final String adminBaseUrl;
  final File instanceIdFile;
  final ViewerInviteRuntime viewerInviteRuntime;
  final ResolvedSlide slide;
  final ThemeData theme;
  final int slideIndex;
  final bool allowVideoPlayback;
  final void Function(int slideIndex, int ms) onReportDesiredDwell;

  @override
  Widget build(BuildContext context) {
    final widgets = parseScreenLayoutWidgets(slide.layoutJson);
    final palette = theme.extension<PaletteTertiaryLayers>();
    return Container(
      decoration: BoxDecoration(
        gradient: palette?.primaryPairGradient,
        color: palette == null
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : null,
      ),
      padding: EdgeInsets.zero,
      child: Center(
        child: _buildWidgets(
          context,
          widgets,
          slide,
          slideIndex,
          allowVideoPlayback,
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
    bool allowVideoPlayback,
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
    // Single full-bleed widgets (like news) need bounded size
    // constraints; putting them in an intrinsic-height Column can pass
    // unbounded height and cause them to render empty.
    if (widgets.length == 1 && widgets.first.type == 'news') {
      final w = widgets.first;
      return SizedBox.expand(
        child: NewsSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
          onReportDesiredDwell: (ms) => onReportDesiredDwell(slideIndex, ms),
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'news_columns') {
      final w = widgets.first;
      return SizedBox.expand(
        child: NewsColumnsSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
          onReportDesiredDwell: (ms) => onReportDesiredDwell(slideIndex, ms),
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'news_stack') {
      final w = widgets.first;
      return SizedBox.expand(
        child: NewsStackSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
          onReportDesiredDwell: (ms) => onReportDesiredDwell(slideIndex, ms),
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'photo') {
      final w = widgets.first;
      return SizedBox.expand(
        child: PhotoSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'photo_collage') {
      final w = widgets.first;
      return SizedBox.expand(
        child: PhotoCollageSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'video') {
      final w = widgets.first;
      return SizedBox.expand(
        child: VideoSlideWidget(
          db: db,
          blobs: blobs,
          slide: slide,
          spec: w,
          theme: theme,
          allowPlayback: allowVideoPlayback,
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'controller_invite') {
      final w = widgets.first;
      return SizedBox.expand(
        child: ControllerInviteSlideWidget(
          displayApiBaseUrl: localRestBaseUrl,
          viewerInviteRuntime: viewerInviteRuntime,
          spec: w,
          theme: theme,
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'data_health') {
      final w = widgets.first;
      return SizedBox.expand(
        child: DataHealthSlideWidget(
          db: db,
          slide: slide,
          spec: w,
          theme: theme,
        ),
      );
    }
    if (widgets.length == 1 && widgets.first.type == 'web_page') {
      final w = widgets.first;
      return SizedBox.expand(
        child: WebPageSlideWidget(
          slide: slide,
          spec: w,
          onReportDesiredDwell: (ms) => onReportDesiredDwell(slideIndex, ms),
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
          const registry = ScreenWidgetRegistry();
          return registry.buildInColumn(
            ScreenWidgetBuildContext(
              db: db,
              blobs: blobs,
              localRestBaseUrl: localRestBaseUrl,
              adminBaseUrl: adminBaseUrl,
              instanceIdFile: instanceIdFile,
              viewerInviteRuntime: viewerInviteRuntime,
              slide: slide,
              theme: theme,
              slideIndex: slideIndex,
              allowVideoPlayback: allowVideoPlayback,
              onReportDesiredDwell: onReportDesiredDwell,
              gap: gap,
            ),
            w,
          );
        }).toList(),
      ),
    );
  }
}
