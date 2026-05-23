import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../dashboard_viewport_scope.dart';
import '../slide_vertical_scroll_timing.dart';
import 'stock_quote_tile.dart';

int _cfgInt(Map<String, dynamic> c, String key, int def) {
  final v = c[key];
  if (v is int) return v;
  if (v is double) return v.round();
  return def;
}

double _cfgDouble(Map<String, dynamic> c, String key, double def) {
  final v = c[key];
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return def;
}

List<String> _symbolFilterFromConfig(Map<String, dynamic> config) {
  final raw = config['symbols'];
  if (raw is! List) return const [];
  return raw
      .whereType<String>()
      .map((s) => s.trim().toUpperCase())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Lists latest [StockQuotes] for enabled symbols in a centered RTL wrap grid.
class StockQuotesSlideWidget extends StatefulWidget {
  const StockQuotesSlideWidget({
    super.key,
    required this.db,
    required this.slide,
    required this.spec,
    required this.theme,
    this.onReportDesiredDwell,
  });

  final AppDatabase db;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final void Function(int desiredDwellMs)? onReportDesiredDwell;

  @override
  State<StockQuotesSlideWidget> createState() => _StockQuotesSlideWidgetState();
}

class _StockQuotesSlideWidgetState extends State<StockQuotesSlideWidget> {
  static const _scrollableEpsilon = 8.0;

  final ScrollController _scroll = ScrollController();
  Timer? _scrollDelayTimer;
  bool _dwellReported = false;
  bool _scrollScheduled = false;
  bool _dwellCheckQueued = false;
  double _viewportScale = 1.0;

  late final List<String> _symbolFilter;
  late final int _scrollDelayMs;
  late final int _trailingHoldMs;
  late final double _scrollPps;
  late final int _minReadMs;

  @override
  void initState() {
    super.initState();
    final c = widget.spec.config;
    _symbolFilter = _symbolFilterFromConfig(c);
    _scrollDelayMs = _cfgInt(c, 'scrollDelayMs', 2500);
    _trailingHoldMs = _cfgInt(c, 'trailingHoldMs', 1500);
    _scrollPps = _cfgDouble(c, 'scrollPixelsPerSecond', 48);
    _minReadMs = _cfgInt(c, 'minReadMs', 6000);
  }

  @override
  void dispose() {
    _scrollDelayTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _queueDwellAndScrollCheck(int symbolCount) {
    if (_dwellReported ||
        _dwellCheckQueued ||
        widget.onReportDesiredDwell == null) {
      return;
    }
    _dwellCheckQueued = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _dwellCheckQueued = false;
      _evaluateDwellAndScroll(symbolCount);
    });
  }

  void _evaluateDwellAndScroll(int symbolCount) {
    if (!mounted || _dwellReported || widget.onReportDesiredDwell == null) {
      return;
    }
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _evaluateDwellAndScroll(symbolCount);
      });
      return;
    }

    final extent = _scroll.position.maxScrollExtent;
    final scrollable = extent > _scrollableEpsilon;
    if (!scrollable && symbolCount >= 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _evaluateDwellAndScroll(symbolCount);
      });
      return;
    }

    _reportDwell(
      scrollable: scrollable,
      maxScrollExtent: scrollable ? extent : 0,
    );

    if (scrollable && !_scrollScheduled) {
      _scrollScheduled = true;
      _scrollDelayTimer?.cancel();
      _scrollDelayTimer = Timer(Duration(milliseconds: _scrollDelayMs), () {
        _runScrollAnimation();
      });
    }
  }

  void _reportDwell({
    required bool scrollable,
    required double maxScrollExtent,
  }) {
    if (_dwellReported || widget.onReportDesiredDwell == null) {
      return;
    }
    final desired = desiredDwellMsForVerticalScroll(
      baseDwellMs: widget.slide.dwellMs,
      minReadMs: _minReadMs,
      scrollable: scrollable,
      scrollDelayMs: _scrollDelayMs,
      trailingHoldMs: _trailingHoldMs,
      maxScrollExtent: maxScrollExtent,
      scrollPixelsPerSecond: _scrollPps * _viewportScale,
    );
    _dwellReported = true;
    widget.onReportDesiredDwell!(desired);
  }

  void _runScrollAnimation() {
    if (!mounted) {
      return;
    }
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _runScrollAnimation(),
      );
      return;
    }
    final position = _scroll.position;
    if (position.maxScrollExtent <= _scrollableEpsilon) {
      return;
    }
    if (position.isScrollingNotifier.value) {
      return;
    }
    if (position.pixels >= position.maxScrollExtent - 1) {
      return;
    }
    final ms = scrollAnimationDurationMs(
      maxScrollExtent: position.maxScrollExtent,
      pixelsPerSecond: _scrollPps * _viewportScale,
    );
    unawaited(
      _scroll.animateTo(
        position.maxScrollExtent,
        duration: Duration(milliseconds: ms < 200 ? 200 : ms),
        curve: Curves.easeInOut,
      ),
    );
  }

  void _ensureScrolledAfterLayout() {
    if (!_scrollScheduled) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runScrollAnimation();
    });
  }

  List<InterestsStockSymbol> _filterSymbols(List<InterestsStockSymbol> all) {
    if (_symbolFilter.isEmpty) return all;
    final want = _symbolFilter.toSet();
    return all.where((s) => want.contains(s.symbol.toUpperCase())).toList();
  }

  Widget _quotesWrap({
    required List<InterestsStockSymbol> symbols,
    required Map<String, StockQuote> byId,
    required double s,
  }) {
    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 24 * s,
      runSpacing: 16 * s,
      children: [
        for (final sym in symbols)
          StockQuoteTile(
            symbol: sym,
            quote: byId[sym.id],
            theme: widget.theme,
            scale: s,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbolsQuery = widget.db.select(widget.db.interestsStockSymbols)
      ..where((t) => t.enabled.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.symbol)]);
    return StreamBuilder<List<InterestsStockSymbol>>(
      stream: symbolsQuery.watch(),
      builder: (context, symbolsSnap) {
        if (!symbolsSnap.hasData) {
          return const SizedBox.shrink();
        }
        final symbols = _filterSymbols(symbolsSnap.data!);
        if (symbols.isEmpty) {
          return _empty('Stock quotes unavailable');
        }
        return StreamBuilder<List<StockQuote>>(
          stream: widget.db.select(widget.db.stockQuotes).watch(),
          builder: (context, quotesSnap) {
            final quotes = quotesSnap.data ?? const <StockQuote>[];
            final byId = {for (final q in quotes) q.symbolId: q};
            final s = DashboardViewportScope.scaleOf(context);
            _viewportScale = s;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24 * s,
                vertical: 16 * s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Markets', style: widget.theme.textTheme.headlineSmall),
                  SizedBox(height: 18 * s),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final ih = constraints.maxHeight;
                        if (!ih.isFinite || ih <= 0) {
                          return const SizedBox.shrink();
                        }
                        _queueDwellAndScrollCheck(symbols.length);
                        _ensureScrolledAfterLayout();
                        return SingleChildScrollView(
                          key: const Key('stock_quotes_wrap_scroll'),
                          controller: _scroll,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: ih),
                            child: Center(
                              child: _quotesWrap(
                                symbols: symbols,
                                byId: byId,
                                s: s,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _empty(String message) {
    if (widget.onReportDesiredDwell != null && !_dwellReported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reportDwell(scrollable: false, maxScrollExtent: 0);
      });
    }
    return Center(
      child: Text(
        message,
        style: widget.theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
