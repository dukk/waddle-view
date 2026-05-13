import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../dashboard_viewport_scope.dart';

/// Renders the latest [StockQuotes] for every enabled [StockSymbols] row.
///
/// Watches both tables and joins in memory so freshly inserted symbols (e.g.
/// from the provider's first run with default symbols) appear immediately,
/// even before a quote has landed.
class StockQuotesSlideWidget extends StatelessWidget {
  const StockQuotesSlideWidget({
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
  Widget build(BuildContext context) {
    final symbolsQuery = db.select(db.stockSymbols)
      ..where((t) => t.enabled.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.symbol)]);
    return StreamBuilder<List<StockSymbol>>(
      stream: symbolsQuery.watch(),
      builder: (context, symbolsSnap) {
        final symbols = symbolsSnap.data ?? const <StockSymbol>[];
        if (symbols.isEmpty) {
          return _empty('Stock quotes unavailable');
        }
        return StreamBuilder<List<StockQuote>>(
          stream: db.select(db.stockQuotes).watch(),
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Markets', style: theme.textTheme.headlineSmall),
                  SizedBox(height: 18 * s),
                  Wrap(
                    spacing: 24 * s,
                    runSpacing: 16 * s,
                    alignment: WrapAlignment.center,
                    children: symbols
                        .map((sym) => _quoteTile(
                              context: context,
                              symbol: sym,
                              quote: byId[sym.id],
                              scale: s,
                            ))
                        .toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _quoteTile({
    required BuildContext context,
    required StockSymbol symbol,
    required StockQuote? quote,
    required double scale,
  }) {
    final price = quote?.currentPrice;
    final percent = quote?.percentChange;
    final priceText = price != null ? '\$${price.toStringAsFixed(2)}' : '—';
    final percentText = percent != null
        ? '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%'
        : '—';
    final trendColor = _trendColor(percent);
    final trendIcon = _trendIcon(percent);
    return SizedBox(
      width: 200 * scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 12 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(symbol.symbol, style: theme.textTheme.titleLarge),
              if (symbol.displayName.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2 * scale),
                  child: Text(
                    symbol.displayName,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(height: 8 * scale),
              Text(
                priceText,
                style: theme.textTheme.headlineSmall,
              ),
              SizedBox(height: 4 * scale),
              Row(
                children: [
                  if (trendIcon != null)
                    Padding(
                      padding: EdgeInsets.only(right: 4 * scale),
                      child: Icon(
                        trendIcon,
                        color: trendColor,
                        size: 18 * scale,
                      ),
                    ),
                  Text(
                    percentText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: trendColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _trendColor(double? percent) {
    if (percent == null) {
      return theme.textTheme.bodyMedium?.color;
    }
    if (percent > 0) {
      return Colors.green.shade400;
    }
    if (percent < 0) {
      return Colors.red.shade400;
    }
    return theme.textTheme.bodyMedium?.color;
  }

  IconData? _trendIcon(double? percent) {
    if (percent == null || percent == 0) {
      return null;
    }
    return percent > 0 ? Icons.trending_up : Icons.trending_down;
  }

  Widget _empty(String text) {
    return Builder(
      builder: (context) {
        final s = DashboardViewportScope.scaleOf(context);
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Text(
            text,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
