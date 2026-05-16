import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/clock.dart';
import 'package:waddle_display/curator/curator_read_port.dart';
import 'package:waddle_display/curator/default_dashboard_curator.dart';
import 'package:waddle_display/curator/ticker_item.dart';
import 'package:waddle_display/curator/ticker_news_candidate.dart';
import 'package:waddle_display/ticker/ticker_curated_repository.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';

class _MapRead implements CuratorReadPort {
  _MapRead(
    this.data, {
    this.currentWeather,
    this.weatherGovAlerts,
    this.tickerDefs,
    this.stockRows,
  });
  final Map<String, String> data;
  final CurrentWeatherTickerData? currentWeather;
  final List<WeatherGovAlertTickerItem>? weatherGovAlerts;
  final List<TickerTapeForCuration>? tickerDefs;
  final List<StockTickerRowForMarquee>? stockRows;

  @override
  Future<Map<String, String>> loadKeyValuesForCuration() async =>
      Map<String, String>.from(data);

  @override
  Future<List<TickerNewsCandidate>> loadNewsCandidatesForTicker() async =>
      const [];

  @override
  Future<CurrentWeatherTickerData?> loadCurrentWeatherForTicker() async =>
      currentWeather;

  @override
  Future<List<WeatherGovAlertTickerItem>> loadWeatherGovAlertsForTicker() async =>
      weatherGovAlerts ?? const [];

  @override
  Future<List<TickerTapeForCuration>> loadTickerTapesForCuration() async =>
      tickerDefs ?? const [];

  @override
  Future<List<StockTickerRowForMarquee>> loadStockRowsForTicker() async =>
      stockRows ?? const [];

  @override
  Future<RejectFilterContext> loadRejectFilterContext() async =>
      const RejectFilterContext.empty();
}

class _RecordingTickerStore implements TickerCuratedRepository {
  List<TickerItem>? last;

  @override
  Future<void> replaceAll(List<TickerItem> items) async {
    last = items;
  }

  @override
  Stream<List<TickerItem>> watchOrdered() async* {
    yield last ?? const [];
  }

  @override
  Future<List<TickerItem>> snapshot() async => last ?? const [];
}

void main() {
  test('refresh writes curated ticker list', () async {
    final store = _RecordingTickerStore();
    final curator = DefaultDashboardCurator(
      read: _MapRead(
        const {},
        tickerDefs: const [
          TickerTapeForCuration(
            id: 'ticker_time',
            tickerType: 'time',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 0,
          ),
          TickerTapeForCuration(
            id: 'ticker_weather',
            tickerType: 'weather',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 10,
            configJson: '{"fallbackText":"Cold"}',
          ),
          TickerTapeForCuration(
            id: 'ticker_news',
            tickerType: 'news',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 20,
            configJson: '{"fallbackText":"Headline"}',
          ),
        ],
      ),
      tickerStore: store,
      clock: FakeClock(DateTime(2026, 1, 2, 15, 0, 0)),
    );
    await curator.refresh();
    expect(store.last, isNotNull);
    expect(store.last!.map((e) => e.kind).toList(), [
      'time',
      'weather',
      'news',
    ]);
    expect(store.last![0].body, '15:00:00');
    expect(store.last![1].body, 'Cold');
    expect(store.last![2].body, 'Headline');
  });

  test('refresh includes stock quotes when ticker_tapes includes stocks', () async {
    final store = _RecordingTickerStore();
    final curator = DefaultDashboardCurator(
      read: _MapRead(
        const {},
        tickerDefs: const [
          TickerTapeForCuration(
            id: 'stock_finnhub',
            tickerType: 'stocks',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 0,
          ),
        ],
        stockRows: [
          (
            symbolId: 'x',
            symbol: 'XX',
            displayName: '',
            currentPrice: 10,
            percentChange: 0.25,
          ),
        ],
      ),
      tickerStore: store,
      clock: FakeClock(DateTime(2026, 1, 2, 15, 0, 0)),
    );
    await curator.refresh();
    expect(store.last, isNotNull);
    final stock = store.last!.singleWhere((e) => e.kind == 'stocks');
    expect(stock.sourceId, 'x');
    expect(stock.body.contains('XX'), isTrue);
    expect(stock.body.contains(r'$10.00'), isTrue);
  });

  test('refresh prefers live current weather for ticker weather item', () async {
    final store = _RecordingTickerStore();
    final curator = DefaultDashboardCurator(
      read: _MapRead(
        const {},
        tickerDefs: const [
          TickerTapeForCuration(
            id: 'ticker_time',
            tickerType: 'time',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 0,
          ),
          TickerTapeForCuration(
            id: 'ticker_weather',
            tickerType: 'weather',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 10,
            configJson: '{"fallbackText":"Fallback Weather"}',
          ),
          TickerTapeForCuration(
            id: 'ticker_news',
            tickerType: 'news',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 20,
            configJson: '{"fallbackText":"Headline"}',
          ),
        ],
        currentWeather: const CurrentWeatherTickerData(
          locationName: 'Atlanta, GA',
          temperatureC: 23,
          description: 'cloudy',
        ),
      ),
      tickerStore: store,
      clock: FakeClock(DateTime(2026, 1, 2, 15, 0, 0)),
    );
    await curator.refresh();
    expect(store.last, isNotNull);
    expect(store.last![1].kind, 'weather');
    expect(store.last![1].body, 'Atlanta, GA: 23° · cloudy');
  });

  test('refresh includes NWS alert lines in weather ticker bundle', () async {
    final store = _RecordingTickerStore();
    final curator = DefaultDashboardCurator(
      read: _MapRead(
        const {},
        currentWeather: const CurrentWeatherTickerData(
          locationName: 'Atlanta, GA',
          temperatureC: 25,
          description: 'fair',
        ),
        weatherGovAlerts: const [
          WeatherGovAlertTickerItem(
            body: 'Atlanta, GA — Advisory — Wind',
            sourceId: 'nws.alert.urn:x',
          ),
        ],
        tickerDefs: const [
          TickerTapeForCuration(
            id: 'w',
            tickerType: 'weather',
            enabled: true,
            frequencyWeight: 1,
            sortOrder: 0,
          ),
        ],
      ),
      tickerStore: store,
      clock: FakeClock(DateTime(2026, 1, 2, 15, 0, 0)),
    );
    await curator.refresh();
    final weatherItems = store.last!.where((e) => e.kind == 'weather').toList();
    expect(weatherItems, hasLength(2));
    expect(weatherItems[0].body, 'Atlanta, GA: 25° · fair');
    expect(weatherItems[1].sourceId, 'nws.alert.urn:x');
  });
}
