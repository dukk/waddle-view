import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

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

/// Lists latest [StockQuotes] for enabled symbols (optional filter + scroll).
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
  final ScrollController _scroll = ScrollController();
  Timer? _scrollDelayTimer;
  bool _dwellReported = false;

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
    _scrollDelayMs = _cfgInt(c, 'scrollDelayMs', 0);
    _trailingHoldMs = _cfgInt(c, 'trailingHoldMs', 1500);
    _scrollPps = _cfgDouble(c, 'scrollPixelsPerSecond', 48);
    _minReadMs = _cfgInt(c, 'minReadMs', 6000);
    _scroll.addListener(_onScrollMetrics);
  }

  @override
  void dispose() {
    _scrollDelayTimer?.cancel();
    _scroll.removeListener(_onScrollMetrics);
    _scroll.dispose();
    super.dispose();
  }

  void _onScrollMetrics() {
    if (_dwellReported || widget.onReportDesiredDwell == null) return;
    if (!_scroll.hasClients) return;
    final extent = _scroll.position.maxScrollExtent;
    if (extent <= 8) {
      if (!_dwellReported && widget.onReportDesiredDwell != null) {
        _dwellReported = true;
        widget.onReportDesiredDwell!(
          widget.slide.dwellMs > _minReadMs ? widget.slide.dwellMs : _minReadMs,
        );
      }
      return;
    }
    _scrollDelayTimer?.cancel();
    _scrollDelayTimer = Timer(Duration(milliseconds: _scrollDelayMs), () {
      if (!mounted || _dwellReported) return;
      final desired = desiredDwellMsForVerticalScroll(
        baseDwellMs: widget.slide.dwellMs,
        minReadMs: _minReadMs,
        scrollable: true,
        scrollDelayMs: _scrollDelayMs,
        trailingHoldMs: _trailingHoldMs,
        maxScrollExtent: extent,
        scrollPixelsPerSecond: _scrollPps,
      );
      _dwellReported = true;
      widget.onReportDesiredDwell!(desired);
      unawaited(
        _scroll.animateTo(
          extent,
          duration: Duration(
            milliseconds: scrollAnimationDurationMs(
              maxScrollExtent: extent,
              pixelsPerSecond: _scrollPps,
            ),
          ),
          curve: Curves.linear,
        ),
      );
    });
  }

  List<InterestsStockSymbol> _filterSymbols(List<InterestsStockSymbol> all) {
    if (_symbolFilter.isEmpty) return all;
    final want = _symbolFilter.toSet();
    return all.where((s) => want.contains(s.symbol.toUpperCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final symbolsQuery = widget.db.select(widget.db.interestsStockSymbols)
      ..where((t) => t.enabled.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.symbol)]);
    return StreamBuilder<List<InterestsStockSymbol>>(
      stream: symbolsQuery.watch(),
      builder: (context, symbolsSnap) {
        final symbols = _filterSymbols(symbolsSnap.data ?? const []);
        if (symbols.isEmpty) {
          return _empty('Stock quotes unavailable');
        }
        return StreamBuilder<List<StockQuote>>(
          stream: widget.db.select(widget.db.stockQuotes).watch(),
          builder: (context, quotesSnap) {
            final quotes = quotesSnap.data ?? const <StockQuote>[];
            final byId = {for (final q in quotes) q.symbolId: q};
            final s = DashboardViewportScope.scaleOf(context);
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
                    child: ListView.separated(
                      controller: _scroll,
                      padding: EdgeInsets.zero,
                      itemCount: symbols.length,
                      separatorBuilder: (_, _) => SizedBox(height: 16 * s),
                      itemBuilder: (context, i) {
                        final sym = symbols[i];
                        return Center(
                          child: StockQuoteTile(
                            symbol: sym,
                            quote: byId[sym.id],
                            theme: widget.theme,
                            scale: s,
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
    return Center(
      child: Text(
        message,
        style: widget.theme.textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
