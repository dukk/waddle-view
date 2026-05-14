import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../curator/ticker_item.dart';
import '../display/dashboard_viewport_scope.dart';
import '../display/content_category_material_icon.dart';
import '../debug/app_debug_log.dart';
import '../theme/display_theme.dart';
import '../theme/ticker_marquee_style.dart';
import '../marquee_cycle_gate.dart';
import 'ticker_curated_repository.dart';
import 'ticker_marquee_duration.dart';

/// Bottom strip: items scroll right-to-left at [pixelsPerSecond].
class TickerMarquee extends StatefulWidget {
  const TickerMarquee({
    super.key,
    required this.repository,
    this.pixelsPerSecond = 80,
    this.separator,
    this.height = 96,
    this.cycleGate,
    this.navigationController,
  });

  final TickerCuratedRepository repository;
  final double pixelsPerSecond;
  final Widget? separator;
  final double height;

  /// When set, [MarqueeCycleGate.notifyMarqueeLoopComplete] runs after each
  /// full scroll loop so [GatedDashboardCurator] can serialize curation.
  final MarqueeCycleGate? cycleGate;
  final TickerMarqueeNavigationController? navigationController;

  @override
  State<TickerMarquee> createState() => _TickerMarqueeState();
}

class _TickerMarqueeState extends State<TickerMarquee>
    with TickerProviderStateMixin {
  final GlobalKey _segmentKey = GlobalKey();
  late AnimationController _controller;
  StreamSubscription<List<TickerItem>>? _subscription;
  List<TickerItem> _items = const [];
  double _segmentWidth = 0;
  bool _wrapWasHigh = false;
  bool _wrapListenerAttached = false;
  final List<List<TickerItem>> _history = <List<TickerItem>>[];
  int _historyCursor = 0;
  int _itemCursor = 0;
  bool _manualNavigationActive = false;
  String? _navigationNotice;
  Timer? _manualIdleTimer;
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
  static const Duration _manualIdleTimeout = Duration(seconds: 3);

  late final VoidCallback _onWrapListener = _handleWrapListener;

  void _handleWrapListener() {
    final gate = widget.cycleGate;
    if (gate == null) {
      return;
    }
    final v = _controller.value;
    if (_wrapWasHigh && v < 0.05) {
      gate.notifyMarqueeLoopComplete();
    }
    _wrapWasHigh = v > 0.92;
  }

  void _detachWrapListener() {
    if (_wrapListenerAttached) {
      _controller.removeListener(_onWrapListener);
      _wrapListenerAttached = false;
    }
    _wrapWasHigh = false;
  }

  void _attachWrapListener() {
    _detachWrapListener();
    _controller.addListener(_onWrapListener);
    _wrapListenerAttached = true;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _subscription = widget.repository.watchOrdered().listen(_onItems);
    widget.navigationController?.addListener(_onNavigationCommand);
  }

  void _onItems(List<TickerItem> next) {
    if (listEquals(next, _items)) {
      // First (and later) empty snapshots match the initial `[]` list; still
      // signal the gate so curation waiters do not block forever.
      if (next.isEmpty) {
        widget.cycleGate?.notifyMarqueeLoopComplete();
      }
      return;
    }
    AppDebugLog.ticker('curated items: ${next.length} (re-layout marquee)');
    _detachWrapListener();
    setState(() {
      _items = next;
      _history.insert(0, List<TickerItem>.unmodifiable(next));
      while (_history.length > 5) {
        _history.removeLast();
      }
      if (!_manualNavigationActive || _historyCursor == 0) {
        _historyCursor = 0;
        _itemCursor = 0;
      }
      _segmentWidth = 0;
    });
    _controller
      ..stop()
      ..reset();
    if (next.isEmpty) {
      widget.cycleGate?.notifyMarqueeLoopComplete();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  void _measureAndStart() {
    if (!mounted) {
      return;
    }
    final ctx = _segmentKey.currentContext;
    if (ctx == null) {
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final w = box.size.width;
    if (w <= 0) {
      AppDebugLog.ticker(
        'marquee: skip animate (segment width ${w.toStringAsFixed(1)}px); notifying cycle gate',
      );
      widget.cycleGate?.notifyMarqueeLoopComplete();
      return;
    }
    if ((_segmentWidth - w).abs() < 0.5 && _controller.isAnimating) {
      return;
    }
    setState(() {
      _segmentWidth = w;
    });
    _controller
      ..stop()
      ..reset()
      ..duration = marqueeScrollDuration(
        contentWidthPx: w,
        pixelsPerSecond: widget.pixelsPerSecond,
      );
    if (_items.isNotEmpty && w > 0) {
      // Seamless wrap: duplicate row + linear 0→1 + repeat jumps 1→0 while
      // the second copy occupies the same pixels the first had at 0.
      _controller.repeat(reverse: false);
      if (widget.cycleGate != null) {
        _attachWrapListener();
      }
      AppDebugLog.ticker(
        'marquee: segment ${w.toStringAsFixed(0)}px, '
        'duration ${_controller.duration?.inMilliseconds ?? 0}ms, '
        '${widget.pixelsPerSecond.toStringAsFixed(0)} px/s',
      );
    }
  }

  @override
  void didUpdateWidget(covariant TickerMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _subscription?.cancel();
      _subscription = widget.repository.watchOrdered().listen(_onItems);
    }
    if (oldWidget.cycleGate != widget.cycleGate) {
      _detachWrapListener();
      if (widget.cycleGate != null && _controller.isAnimating) {
        _attachWrapListener();
      }
    }
    if (oldWidget.navigationController != widget.navigationController) {
      oldWidget.navigationController?.removeListener(_onNavigationCommand);
      widget.navigationController?.addListener(_onNavigationCommand);
    }
  }

  @override
  void dispose() {
    widget.navigationController?.removeListener(_onNavigationCommand);
    _manualIdleTimer?.cancel();
    _overlayFadeController.dispose();
    _detachWrapListener();
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<TickerItem> get _visibleProgram =>
      _history.isEmpty ? const [] : _history[_historyCursor];

  void _onNavigationCommand() {
    final direction = widget.navigationController?.direction;
    if (direction == null || direction == 0) {
      return;
    }
    if (direction < 0) {
      _navigateBackward();
    } else {
      _navigateForward();
    }
  }

  void _beginManualNavigation() {
    _controller.stop();
    _manualNavigationActive = true;
    _overlayFadeController.forward();
    _manualIdleTimer?.cancel();
    _manualIdleTimer = Timer(_manualIdleTimeout, _onManualNavigationIdle);
  }

  void _onManualNavigationIdle() {
    if (!mounted) {
      return;
    }
    setState(() {
      _manualNavigationActive = false;
      _navigationNotice = null;
      _historyCursor = 0;
      _itemCursor = 0;
    });
    _overlayFadeController.reverse();
    if (_items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    }
  }

  void _navigateBackward() {
    if (_history.isEmpty || _visibleProgram.isEmpty) {
      return;
    }
    setState(() {
      _beginManualNavigation();
      if (_itemCursor > 0) {
        _itemCursor -= 1;
        _navigationNotice = null;
        return;
      }
      final olderProgramIndex = _historyCursor + 1;
      if (olderProgramIndex < _history.length) {
        _historyCursor = olderProgramIndex;
        _itemCursor = _visibleProgram.length - 1;
        _navigationNotice = null;
        return;
      }
      _navigationNotice = 'You have reached the end of ticker history.';
    });
  }

  void _navigateForward() {
    if (_history.isEmpty || _visibleProgram.isEmpty) {
      return;
    }
    setState(() {
      _beginManualNavigation();
      if (_itemCursor < _visibleProgram.length - 1) {
        _itemCursor += 1;
        _navigationNotice = null;
        return;
      }
      if (_historyCursor > 0) {
        _historyCursor -= 1;
        _itemCursor = 0;
        _navigationNotice = null;
        return;
      }
      _navigationNotice = 'End of current ticker program. Waiting for a new program.';
    });
  }

  Widget _defaultSeparator(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * s),
      child: Text(
        '\u00B7',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _tickerItemLine(BuildContext context, TickerItem item) {
    final base = Theme.of(context).textTheme.titleLarge;
    final rssTheme = Theme.of(context).extension<TickerMarqueeStyle>();
    if (_isWeatherAlertTickerItem(item)) {
      return _weatherAlertLine(context, item, base);
    }
    final weatherIcon = _weatherIconForTicker(item);
    if (weatherIcon != null) {
      final s = DashboardViewportScope.scaleOf(context);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            weatherIcon,
            size: 26 * s,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 8 * s),
          Text(
            item.body,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: base,
          ),
        ],
      );
    }
    final rss = item.rss;
    if (rss != null && rssTheme != null && base != null) {
      final children = <InlineSpan>[];
      if (rss.showSource && rss.sourceTitle.isNotEmpty) {
        final iconName = rss.sourceIconName?.trim();
        if (iconName != null && iconName.isNotEmpty) {
          final s = DashboardViewportScope.scaleOf(context);
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: 6 * s),
                child: Icon(
                  contentCategoryMaterialIcon(iconName),
                  size: 22 * s,
                  color:
                      Theme.of(context).iconTheme.color ??
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        children.add(
          TextSpan(
            text: '${rss.sourceTitle} ',
            style: base.merge(rssTheme.rssSourceStyle),
          ),
        );
      }
      children.add(
        TextSpan(
          text: '${rss.articleTitle}:',
          style: base.merge(rssTheme.rssTitleStyle),
        ),
      );
      if (rss.summary.isNotEmpty) {
        children.add(
          TextSpan(
            text: ' ${rss.summary}',
            style: base.merge(rssTheme.rssSummaryStyle),
          ),
        );
      }
      return Text.rich(
        TextSpan(children: children),
        maxLines: 1,
        overflow: TextOverflow.clip,
      );
    }
    return Text(
      item.body,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: base,
    );
  }

  /// Weather alerts arrive with [TickerItem.kind] `weather` and a
  /// `nws.alert.*` [TickerItem.sourceId]; see
  /// `drift_curator_read_port.loadWeatherGovAlertsForTicker`.
  bool _isWeatherAlertTickerItem(TickerItem item) {
    if (item.kind != 'weather') {
      return false;
    }
    final id = item.sourceId;
    return id != null && id.startsWith('nws.alert.');
  }

  Widget _weatherAlertLine(
    BuildContext context,
    TickerItem item,
    TextStyle? base,
  ) {
    final s = DashboardViewportScope.scaleOf(context);
    final accent = Theme.of(context).colorScheme.error;
    final iconSize = 28 * s;
    Widget warningIcon() => Icon(
      Icons.warning_amber_rounded,
      size: iconSize,
      color: accent,
    );
    final accentBorderSide = BorderSide(color: accent, width: 2 * s);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: accentBorderSide,
          bottom: accentBorderSide,
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 2 * s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          warningIcon(),
          SizedBox(width: 8 * s),
          Text(
            item.body,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: base?.copyWith(color: accent, fontWeight: FontWeight.w700),
          ),
          SizedBox(width: 8 * s),
          warningIcon(),
        ],
      ),
    );
  }

  IconData? _weatherIconForTicker(TickerItem item) {
    if (item.kind != 'weather') {
      return null;
    }
    final value = item.body.toLowerCase();
    if (value.contains('snow') || value.contains('sleet') || value.contains('ice')) {
      return Icons.ac_unit;
    }
    if (value.contains('thunder') || value.contains('storm')) {
      return Icons.thunderstorm;
    }
    if (value.contains('rain') || value.contains('drizzle') || value.contains('shower')) {
      return Icons.umbrella;
    }
    if (value.contains('cloud') || value.contains('overcast')) {
      return Icons.cloud;
    }
    if (value.contains('fog') || value.contains('mist') || value.contains('haze')) {
      return Icons.foggy;
    }
    return Icons.wb_sunny;
  }

  List<Widget> _segmentChildren(BuildContext context) {
    final sep = widget.separator ?? _defaultSeparator(context);
    final out = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      if (i > 0) {
        out.add(sep);
      }
      out.add(_tickerItemLine(context, _items[i]));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    final radius = BorderRadius.circular(8 * s);
    final palette = Theme.of(context).extension<PaletteTertiaryLayers>();
    final tickerBackground = BoxDecoration(
      gradient: palette?.secondaryPairGradient,
      color: palette == null
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      borderRadius: radius,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : widget.height;

        if (_items.isEmpty) {
          return SizedBox(
            height: h,
            child: DecoratedBox(
              decoration: tickerBackground,
              child: Center(
                child: Text(
                  '\u2014',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          );
        }

        if (_manualNavigationActive && _visibleProgram.isNotEmpty) {
          final current = _visibleProgram[_itemCursor];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: h,
                child: DecoratedBox(
                  decoration: tickerBackground,
                  child: Center(child: _tickerItemLine(context, current)),
                ),
              ),
              Positioned(
                left: 8 * s,
                right: 8 * s,
                bottom: h + (8 * s),
                child: FadeTransition(
                  opacity: _overlayFade,
                  child: _TickerNavigationOverlay(
                    items: _visibleProgram,
                    currentIndex: _itemCursor,
                    notice: _navigationNotice,
                  ),
                ),
              ),
            ],
          );
        }

        final segment = Row(
          key: _segmentKey,
          mainAxisSize: MainAxisSize.min,
          children: _segmentChildren(context),
        );
        final segmentCopy = ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _segmentChildren(context),
          ),
        );

        return SizedBox(
          height: h,
          child: DecoratedBox(
            decoration: tickerBackground,
            child: ClipRRect(
              borderRadius: radius,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                primary: false,
                clipBehavior: Clip.hardEdge,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    if (_segmentWidth <= 0) {
                      return child!;
                    }
                    final dx = -(_controller.value * _segmentWidth);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      filterQuality: FilterQuality.low,
                      child: child,
                    );
                  },
                  child: RepaintBoundary(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        segment,
                        segmentCopy,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TickerMarqueeNavigationController extends ChangeNotifier {
  int _direction = 0;

  int get direction => _direction;

  void navigateBackward() {
    _direction = -1;
    notifyListeners();
  }

  void navigateForward() {
    _direction = 1;
    notifyListeners();
  }
}

class _TickerNavigationOverlay extends StatelessWidget {
  const _TickerNavigationOverlay({
    required this.items,
    required this.currentIndex,
    required this.notice,
  });

  final List<TickerItem> items;
  final int currentIndex;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: i == currentIndex
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            items[i].kind,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (notice != null) ...[
              const SizedBox(height: 6),
              Text(notice!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
