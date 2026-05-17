import 'package:waddle_shared/curation/reject_filter_context.dart';

import '../curator/curator_read_port.dart';
import '../curator/ticker_item.dart';

/// Expands one [TickerTapeForCuration] into marquee items.
typedef TickerSourceExpander = List<TickerItem> Function(
  TickerTapeForCuration def,
  TickerExpandContext ctx,
);

class TickerExpandContext {
  const TickerExpandContext({
    required this.kv,
    required this.nowLocal,
    required this.rssItems,
    this.currentWeather,
    this.stockRows = const [],
    this.weatherGovAlerts = const [],
    this.rejectCtx,
  });

  final Map<String, String> kv;
  final DateTime nowLocal;
  final List<TickerItem> rssItems;
  final CurrentWeatherTickerData? currentWeather;
  final List<StockTickerRowForMarquee> stockRows;
  final List<WeatherGovAlertTickerItem> weatherGovAlerts;
  final RejectFilterContext? rejectCtx;
}

class TickerSourceRegistry {
  final Map<String, TickerSourceExpander> _expanders = {};

  void register(String tickerType, TickerSourceExpander expander) {
    _expanders[tickerType.trim().toLowerCase()] = expander;
  }

  TickerSourceExpander? lookup(String tickerType) {
    return _expanders[tickerType.trim().toLowerCase()];
  }

  Iterable<String> get registeredTypes => _expanders.keys;
}
