import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/curator/ticker_item.dart';
import 'package:waddle_display/debug/operator_telemetry_hub.dart';

void main() {
  test('provider lines ring buffer drops oldest', () {
    final hub = OperatorTelemetryHub(maxProviderLines: 3);
    hub.addProviderLine('a');
    hub.addProviderLine('b');
    hub.addProviderLine('c');
    hub.addProviderLine('d');
    final snap = hub.snapshotProviderLines();
    expect(snap.length, 3);
    expect(snap.map((e) => e['message']), ['b', 'c', 'd']);
  });

  test('screen program snapshot includes screen_type', () {
    final hub = OperatorTelemetryHub(maxScreenPrograms: 10);
    hub.recordScreenProgram(
      reason: 'new_program',
      slides: const [
        ResolvedSlide(
          screenId: 's1',
          dwellMs: 5000,
          layoutJson: '{"type":"weather"}',
          randomChoices: {'k': 'v'},
        ),
      ],
      screenTypeById: {'s1': 'weather'},
    );
    final snap = hub.snapshotScreenPrograms();
    expect(snap.length, 1);
    final slides = snap.first['slides'] as List<dynamic>;
    expect(slides.length, 1);
    final slide = slides.first as Map;
    expect(slide['screen_id'], 's1');
    expect(slide['screen_type'], 'weather');
    expect(slide['dwell_ms'], 5000);
    expect(slide['random_choices'], {'k': 'v'});
  });

  test('ticker program serializes rss', () {
    final hub = OperatorTelemetryHub(maxTickerPrograms: 5);
    hub.recordTickerProgram([
      TickerItem(
        kind: 'news',
        body: 'hello',
        sourceId: 'id1',
        rss: const TickerRssSegments(
          sourceTitle: 'Src',
          articleTitle: 'Title',
          summary: 'Sum',
          showSource: true,
        ),
      ),
    ]);
    final snap = hub.snapshotTickerPrograms();
    expect(snap.length, 1);
    final items = snap.first['items'] as List<dynamic>;
    expect((items.first as Map)['kind'], 'news');
    expect((items.first as Map)['rss'], isNotNull);
  });

  test('sinceMs filters snapshots', () async {
    final hub = OperatorTelemetryHub(maxProviderLines: 100);
    hub.addEngineLine('old');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final t0 = DateTime.now().millisecondsSinceEpoch;
    hub.addEngineLine('new');
    final filtered = hub.snapshotProviderLines(sinceMs: t0);
    expect(filtered.length, 1);
    expect(filtered.first['message'], 'new');
  });

  test('addProviderFail and addEngineFail append lines', () {
    final hub = OperatorTelemetryHub(maxProviderLines: 20);
    hub.addProviderFail('ctx', StateError('x'), StackTrace.current);
    hub.addEngineFail('eng', ArgumentError('y'), StackTrace.current);
    final snap = hub.snapshotProviderLines();
    expect(snap.length, 2);
    expect((snap[0]['message'] as String).contains('FAIL ctx'), isTrue);
    expect((snap[1]['message'] as String).contains('FAIL eng'), isTrue);
  });

  test('snapshotPrograms respects limit', () {
    final hub = OperatorTelemetryHub(maxScreenPrograms: 2);
    for (var i = 0; i < 5; i++) {
      hub.recordScreenProgram(
        reason: 'r$i',
        slides: const [
          ResolvedSlide(
            screenId: 's',
            dwellMs: 1,
            layoutJson: '{}',
            randomChoices: {},
          ),
        ],
        screenTypeById: const {'s': 'weather'},
      );
    }
    final limited = hub.snapshotScreenPrograms(limit: 2);
    expect(limited.length, 2);
  });
}

