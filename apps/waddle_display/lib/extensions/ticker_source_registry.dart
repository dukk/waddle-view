import 'package:waddle_shared/curation/reject_filter_context.dart';

import '../curator/curator_read_port.dart';
import '../curator/ticker_curation.dart';
import '../curator/ticker_item.dart';
import '../curator/ticker_news_candidate.dart';

/// Expands one [TickerTapeForCuration] into marquee items.
typedef TickerSourceExpander = List<TickerItem> Function(
  TickerTapeForCuration def,
  TickerExpandContext ctx,
);

class TickerExpandContext {
  const TickerExpandContext({
    required this.kv,
    required this.nowLocal,
    required this.newsCandidates,
    required this.curatorTickerConfig,
    this.quoteTickerItems = const [],
    this.quoteCategoryIdsByQuoteId = const {},
    this.weatherByLocationId = const {},
    required this.displayTemperatureUnit,
    this.stockRows = const [],
    this.weatherGovAlerts = const [],
    this.rejectCtx,
  });

  final Map<String, String> kv;
  final DateTime nowLocal;
  final List<TickerNewsCandidate> newsCandidates;
  final CuratorTickerConfig curatorTickerConfig;
  final List<TickerItem> quoteTickerItems;
  final Map<String, Set<String>> quoteCategoryIdsByQuoteId;
  final Map<String, CurrentWeatherTickerData> weatherByLocationId;
  final String displayTemperatureUnit;
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
