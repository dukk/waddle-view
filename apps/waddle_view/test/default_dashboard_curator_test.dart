import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/clock.dart';
import 'package:waddle_view/curator/curator_read_port.dart';
import 'package:waddle_view/curator/default_dashboard_curator.dart';
import 'package:waddle_view/curator/ticker_item.dart';
import 'package:waddle_view/curator/ticker_news_candidate.dart';
import 'package:waddle_view/ticker/ticker_curated_repository.dart';

class _MapRead implements CuratorReadPort {
  _MapRead(this.data, {this.currentWeather});
  final Map<String, String> data;
  final CurrentWeatherTickerData? currentWeather;

  @override
  Future<Map<String, String>> loadKeyValuesForCuration() async =>
      Map<String, String>.from(data);

  @override
  Future<List<TickerNewsCandidate>> loadNewsCandidatesForTicker() async =>
      const [];

  @override
  Future<CurrentWeatherTickerData?> loadCurrentWeatherForTicker() async =>
      currentWeather;
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
