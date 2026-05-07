import '../clock.dart';
import '../debug/app_debug_log.dart';
import '../ticker/ticker_curated_repository.dart';
import 'curator_read_port.dart';
import 'dashboard_curator.dart';
import 'ticker_curation.dart';

class DefaultDashboardCurator implements DashboardCurator {
  DefaultDashboardCurator({
    required CuratorReadPort read,
    required TickerCuratedRepository tickerStore,
    required Clock clock,
  }) : _read = read,
       _tickerStore = tickerStore,
       _clock = clock;

  final CuratorReadPort _read;
  final TickerCuratedRepository _tickerStore;
  final Clock _clock;

  @override
  Future<void> refresh() async {
    final kv = await _read.loadKeyValuesForCuration();
    final news = await _read.loadNewsCandidatesForTicker();
    final currentWeather = await _read.loadCurrentWeatherForTicker();
    final weatherGovAlerts = await _read.loadWeatherGovAlertsForTicker();
    final tickerDefs = await _read.loadTickerDefinitionsForCuration();
    final stockRows = await _read.loadStockRowsForTicker();
    final items = buildTickerItemsForMarquee(
      kv: kv,
      nowLocal: _clock.now().toLocal(),
      newsCandidates: news,
      currentWeather: currentWeather,
      definitions: tickerDefs,
      stockRows: stockRows,
      weatherGovAlerts: weatherGovAlerts,
    );
    await _tickerStore.replaceAll(items);
    final kinds = items.map((e) => e.kind).join(', ');
    AppDebugLog.curator(
      'refresh: ${items.length} ticker item(s) kinds=[$kinds]',
    );
  }
}
