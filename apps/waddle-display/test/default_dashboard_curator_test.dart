import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/clock.dart';
import 'package:waddle_display/curator/curator_read_port.dart';
import 'package:waddle_display/curator/default_dashboard_curator.dart';
import 'package:waddle_display/curator/ticker_item.dart';
import 'package:waddle_display/curator/ticker_news_candidate.dart';
import 'package:waddle_display/ticker/ticker_curated_repository.dart';

class _MapRead implements CuratorReadPort {
  _MapRead(
    this.data, {
    this.currentWeather,
    this.tickerDefs,
    this.stockRows,
  });
  final Map<String, String> data;
  final CurrentWeatherTickerData? currentWeather;
  final List<TickerDefinitionForCuration>? tickerDefs;
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
  Future<List<TickerDefinitionForCuration>> loadTickerDefinitionsForCuration() async =>
      tickerDefs ?? const [];

  @override
  Future<List<StockTickerRowForMarquee>> loadStockRowsForTicker() async =>
      stockRows ?? const [];
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
      read: _MapRead({
        'ticker.marquee.news': 'Headline',
        'ticker.marquee.weather': 'Cold',
      }),
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

  test('refresh includes stock quotes when ticker_definitions includes stocks', () async {
    final store = _RecordingTickerStore();
    final curator = DefaultDashboardCurator(
      read: _MapRead(
        const {},
        tickerDefs: const [
          TickerDefinitionForCuration(
            id: 'stocks',
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
        {
          'ticker.marquee.news': 'Headline',
          'ticker.marquee.weather': 'Fallback Weather',
        },
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
}
