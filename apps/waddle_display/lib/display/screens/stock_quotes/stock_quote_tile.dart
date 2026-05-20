import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../../../theme/display_theme.dart';

/// One stock quote card (symbol, price, percent change) used by the slide and overlay.
class StockQuoteTile extends StatelessWidget {
  const StockQuoteTile({
    super.key,
    required this.symbol,
    required this.quote,
    required this.theme,
    required this.scale,
  });

  final InterestsStockSymbol symbol;
  final StockQuote? quote;
  final ThemeData theme;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final price = quote?.currentPrice;
    final percent = quote?.percentChange;
    final priceText = price != null ? '\$${price.toStringAsFixed(2)}' : '—';
    final percentText = percent != null
        ? '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%'
        : '—';
    final trendColor = _trendColor(percent);
    final trendIcon = _trendIcon(percent);
    return SizedBox(
      width: 248 * scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.slidePanelColor,
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 12 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  priceText,
                  style: theme.textTheme.headlineSmall,
                  maxLines: 1,
                  softWrap: false,
                ),
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
}
