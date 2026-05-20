import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_stock_quote_settings.dart';

import '../screens/stock_quotes/stock_quote_tile.dart';
import 'clock_overlay_layout.dart';

/// Renders one or more positioned stock quote tiles (overlay type `stock_quote`).
class StockQuoteOverlay extends StatelessWidget {
  const StockQuoteOverlay({
    super.key,
    required this.db,
    required this.settingsList,
    required this.theme,
  });

  final AppDatabase db;
  final List<StockQuoteOverlaySettings> settingsList;
  final ThemeData theme;

  static const double _tileDesignWidth = 248;

  @override
  Widget build(BuildContext context) {
    if (settingsList.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClockOverlayLayout(
      placements: settingsList.map((s) => s.placement).toList(),
      childBuilder: (context, index, placement, blockWidth) {
        final settings = settingsList[index];
        final tileScale = blockWidth / _tileDesignWidth;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: _StockQuoteOverlayInstance(
            db: db,
            symbolId: settings.symbolId,
            theme: theme,
            tileScale: tileScale,
          ),
        );
      },
    );
  }
}

class _StockQuoteOverlayInstance extends StatelessWidget {
  const _StockQuoteOverlayInstance({
    required this.db,
    required this.symbolId,
    required this.theme,
    required this.tileScale,
  });

  final AppDatabase db;
  final String symbolId;
  final ThemeData theme;
  final double tileScale;

  @override
  Widget build(BuildContext context) {
    final symbolQuery = db.select(db.interestsStockSymbols)
      ..where((t) => t.id.equals(symbolId));
    return StreamBuilder<List<InterestsStockSymbol>>(
      stream: symbolQuery.watch(),
      builder: (context, symbolSnap) {
        final symbol = symbolSnap.data?.firstOrNull;
        if (symbol == null) {
          return _emptyLabel(context, 'Stock quote unavailable');
        }
        return StreamBuilder<List<StockQuote>>(
          stream: db.select(db.stockQuotes).watch(),
          builder: (context, quotesSnap) {
            final quotes = quotesSnap.data ?? const <StockQuote>[];
            StockQuote? quote;
            for (final q in quotes) {
              if (q.symbolId == symbolId) {
                quote = q;
                break;
              }
            }
            return StockQuoteTile(
              symbol: symbol,
              quote: quote,
              theme: theme,
              scale: tileScale,
            );
          },
        );
      },
    );
  }

  Widget _emptyLabel(BuildContext context, String text) {
    return SizedBox(
      width: StockQuoteOverlay._tileDesignWidth * tileScale,
      child: Text(
        text,
        style: theme.textTheme.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
