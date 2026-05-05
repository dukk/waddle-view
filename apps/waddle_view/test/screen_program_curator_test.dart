import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';

ScreenCandidate _c({
  required String id,
  int dwellMs = 60000,
  int weight = 100,
  String layout = '{"v":1,"layout":"single","widgets":[]}',
}) {
  return ScreenCandidate(
    id: id,
    dwellMs: dwellMs,
    frequencyWeight: weight,
    minGapBetweenShowsMs: 0,
    layoutJson: layout,
    enabled: true,
  );
}

void main() {
  test('buildProgram returns empty when no enabled screens', () {
    expect(
      ScreenProgramCurator.buildProgram(
        screens: [
          ScreenCandidate(
            id: 'x',
            dwellMs: 1000,
            frequencyWeight: 1,
            minGapBetweenShowsMs: 0,
            layoutJson: '{}',
            enabled: false,
          ),
        ],
        programDurationMs: 180000,
        recentScreenIdsOldestFirst: const [],
        historyDepth: 5,
        random: Random(1),
      ),
      isEmpty,
    );
  });

  test('buildProgram fills budget with dwell slices', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'a', dwellMs: 50000),
      ],
      programDurationMs: 180000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
    );
    expect(slides.length, 4);
    expect(slides.every((s) => s.screenId == 'a'), isTrue);
    expect(slides.fold<int>(0, (a, s) => a + s.dwellMs), 180000);
  });

  test('prefers screen absent from recent history when weights tie', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'often', dwellMs: 60000, weight: 100),
        _c(id: 'fresh', dwellMs: 60000, weight: 100),
      ],
      programDurationMs: 120000,
      recentScreenIdsOldestFirst: const ['often', 'often', 'often'],
      historyDepth: 5,
      random: Random(42),
    );
    final ids = slides.map((e) => e.screenId).toList();
    expect(slides.length, 2);
    expect(ids.contains('fresh'), isTrue);
  });

  test('dedupes random pool picks within one program', () {
    const layout = '''
{"v":1,"layout":"single","widgets":[
  {"type":"photo_random","slot":"left","config":{"pool":"pix"}},
  {"type":"photo_random","slot":"right","config":{"pool":"pix"}}
]}''';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'photos', dwellMs: 30000, layout: layout),
      ],
      programDurationMs: 30000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(7),
      randomPools: {
        'pix': ['a', 'b', 'c'],
      },
    );
    expect(slides, hasLength(1));
    final left = slides.single.randomChoices['left_photo_random'];
    final right = slides.single.randomChoices['right_photo_random'];
    expect(left, isNotNull);
    expect(right, isNotNull);
    expect(left, isNot(equals(right)));
  });

  test('parseWidgets reads widget types', () {
    final w = parseScreenLayoutWidgets(
      jsonEncode({
        'v': 1,
        'widgets': [
          {'type': 'static_text', 'slot': 'main'},
        ],
      }),
    );
    expect(w.single.type, 'static_text');
    expect(w.single.slot, 'main');
  });

  test('historyWindowSlice returns oldest→newest tail', () {
    expect(
      ScreenProgramCurator.historyWindowSlice(
        const ['a', 'b', 'c', 'd'],
        2,
      ),
      const ['c', 'd'],
    );
    expect(
      ScreenProgramCurator.historyWindowSlice(const ['a'], 5),
      const ['a'],
    );
    expect(ScreenProgramCurator.historyWindowSlice(const [], 3), isEmpty);
    expect(ScreenProgramCurator.historyWindowSlice(const ['x'], 0), isEmpty);
  });

  test('curatedProgramDebugLogLines describes slides and consecutive dupes', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'a', dwellMs: 50000),
      ],
      programDurationMs: 100000,
      recentScreenIdsOldestFirst: const ['x', 'y'],
      historyDepth: 5,
      random: Random(0),
    );
    final lines = ScreenProgramCurator.curatedProgramDebugLogLines(
      program: slides,
      programDurationMs: 100000,
      historyDepth: 5,
      recentScreenIdsOldestFirst: const ['x', 'y'],
    );
    expect(lines.length, greaterThanOrEqualTo(2));
    expect(lines.first, contains('curated slides: 2'));
    expect(lines.first, contains('weightWindow(oldest→newest)=[x, y]'));
    expect(lines[1], contains('[0] a'));
    expect(lines[1], contains('[1] a'));
    expect(lines, contains('consecutive duplicate screenId="a" at slide indices 0→1'));

    final emptyLines = ScreenProgramCurator.curatedProgramDebugLogLines(
      program: const [],
      programDurationMs: 1000,
      historyDepth: 3,
      recentScreenIdsOldestFirst: const [],
    );
    expect(emptyLines.single, contains('curated slides: 0'));
  });
}
