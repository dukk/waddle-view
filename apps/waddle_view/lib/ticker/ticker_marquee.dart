import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../curator/ticker_item.dart';
import '../debug/app_debug_log.dart';
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
  });

  final TickerCuratedRepository repository;
  final double pixelsPerSecond;
  final Widget? separator;
  final double height;

  /// When set, [MarqueeCycleGate.notifyMarqueeLoopComplete] runs after each
  /// full scroll loop so [GatedDashboardCurator] can serialize curation.
  final MarqueeCycleGate? cycleGate;

  @override
  State<TickerMarquee> createState() => _TickerMarqueeState();
}

class _TickerMarqueeState extends State<TickerMarquee>
    with SingleTickerProviderStateMixin {
  final GlobalKey _segmentKey = GlobalKey();
  late AnimationController _controller;
  StreamSubscription<List<TickerItem>>? _subscription;
  List<TickerItem> _items = const [];
  double _segmentWidth = 0;
  bool _wrapWasHigh = false;
  bool _wrapListenerAttached = false;

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
  }

  @override
  void dispose() {
    _detachWrapListener();
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _defaultSeparator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
    final rss = item.rss;
    if (rss != null && rssTheme != null && base != null) {
      final children = <InlineSpan>[];
      if (rss.showSource && rss.sourceTitle.isNotEmpty) {
        children.add(
          TextSpan(
            text: '[${rss.sourceTitle}] ',
            style: base.merge(rssTheme.rssSourceStyle),
          ),
        );
      }
      children.add(
        TextSpan(
          text: rss.articleTitle,
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
    if (_items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '\u2014',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
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
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
  }
}
