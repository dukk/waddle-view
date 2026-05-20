import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../dashboard_viewport_scope.dart';
import 'stock_quote_tile.dart';

/// Renders the latest [StockQuotes] for every enabled [InterestsStockSymbols] row.
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
    final symbolsQuery = db.select(db.interestsStockSymbols)
      ..where((t) => t.enabled.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.symbol)]);
    return StreamBuilder<List<InterestsStockSymbol>>(
      stream: symbolsQuery.watch(),
      builder: (context, symbolsSnap) {
        final symbols = symbolsSnap.data ?? const <InterestsStockSymbol>[];
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
                        .map(
                          (sym) => StockQuoteTile(
                            symbol: sym,
                            quote: byId[sym.id],
                            theme: theme,
                            scale: s,
                          ),
                        )
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
