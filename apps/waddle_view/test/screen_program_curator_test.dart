import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/curator/curator_content_pools.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';

ScreenCandidate _c({
  required String id,
  int dwellMs = 60000,
  int weight = 100,
  int minPlacementsPerProgram = 0,
  int? maxPlacementsPerProgram,
  String dataKey = '',
  String layout = '{"v":1,"layout":"single","widgets":[]}',
}) {
  return ScreenCandidate(
    id: id,
    dwellMs: dwellMs,
    frequencyWeight: weight,
    minGapBetweenShowsMs: 0,
    minPlacementsPerProgram: minPlacementsPerProgram,
    maxPlacementsPerProgram: maxPlacementsPerProgram,
    dataKey: dataKey,
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

  test('dedupes joke picks across slides in one program', () {
    const layout = '{"v":1,"layout":"single","widgets":['
        '{"type":"joke","slot":"main","config":{}}'
        ']}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'j1', dwellMs: 30000, layout: layout),
        _c(id: 'j2', dwellMs: 30000, layout: layout),
      ],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(2),
      randomPools: {
        'joke': ['ja', 'jb', 'jc'],
      },
    );
    expect(slides, hasLength(2));
    final a = slides[0].randomChoices['main_joke'];
    final b = slides[1].randomChoices['main_joke'];
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(a, isNot(equals(b)));
  });

  test('dedupes rss_article picks across slides in one program', () {
    const layout = '{"v":1,"layout":"single","widgets":['
        '{"type":"rss_article","slot":"main","config":{}}'
        ']}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'n1', dwellMs: 30000, layout: layout),
        _c(id: 'n2', dwellMs: 30000, layout: layout),
      ],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(5),
      randomPools: {
        'rss': ['r1', 'r2'],
      },
    );
    expect(slides, hasLength(2));
    final x = slides[0].randomChoices['main_rss_article'];
    final y = slides[1].randomChoices['main_rss_article'];
    expect(x, isNotNull);
    expect(y, isNotNull);
    expect(x, isNot(equals(y)));
  });

  test('rss_article_columns assigns one distinct rss id per column', () {
    const layout = '{"v":1,"layout":"single","widgets":['
        '{"type":"rss_article_columns","slot":"main","config":{"columnCount":3}}'
        ']}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [_c(id: 'nc', dwellMs: 30000, layout: layout)],
      programDurationMs: 30000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(11),
      randomPools: {
        'rss': ['r1', 'r2', 'r3', 'r4'],
      },
    );
    expect(slides, hasLength(1));
    final m = slides.single.randomChoices;
    final a = m['main_rss_article_columns_0'];
    final b = m['main_rss_article_columns_1'];
    final c = m['main_rss_article_columns_2'];
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(c, isNotNull);
    expect({a, b, c}.length, 3);
  });

  test('rss_article_stack assigns two distinct rss ids', () {
    const layout = '{"v":1,"layout":"single","widgets":['
        '{"type":"rss_article_stack","slot":"main","config":{}}'
        ']}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [_c(id: 'ns', dwellMs: 30000, layout: layout)],
      programDurationMs: 30000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(19),
      randomPools: {
        'rss': ['r1', 'r2', 'r3'],
      },
    );
    expect(slides, hasLength(1));
    final m = slides.single.randomChoices;
    final a = m['main_rss_article_stack_0'];
    final b = m['main_rss_article_stack_1'];
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(a, isNot(equals(b)));
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

  test('screen max placements per program is respected', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'limited', dwellMs: 30000, maxPlacementsPerProgram: 1),
        _c(id: 'fallback', dwellMs: 30000),
      ],
      programDurationMs: 180000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(3),
    );
    final limitedCount = slides.where((s) => s.screenId == 'limited').length;
    expect(limitedCount, lessThanOrEqualTo(1));
  });

  test('screen min placements per program is prioritized when feasible', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'must_show', dwellMs: 30000, minPlacementsPerProgram: 2),
        _c(id: 'other', dwellMs: 30000),
      ],
      programDurationMs: 120000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(9),
    );
    final mustShowCount = slides.where((s) => s.screenId == 'must_show').length;
    expect(mustShowCount, greaterThanOrEqualTo(2));
  });

  test('data key max placements applies across multiple screens', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'news_a', dwellMs: 30000, dataKey: 'news'),
        _c(id: 'news_b', dwellMs: 30000, dataKey: 'news'),
        _c(id: 'other', dwellMs: 30000),
      ],
      programDurationMs: 150000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(4),
      dataKeyLimits: const {
        'news': DataKeyProgramLimit(maxPlacementsPerProgram: 1),
      },
    );
    final newsCount = slides.where((s) => s.screenId.startsWith('news_')).length;
    expect(newsCount, lessThanOrEqualTo(1));
  });

  test('data key min placements is prioritized across screens', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'clock_digital', dwellMs: 30000, dataKey: 'clock'),
        _c(id: 'clock_analog', dwellMs: 30000, dataKey: 'clock'),
        _c(id: 'other', dwellMs: 30000),
      ],
      programDurationMs: 150000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(11),
      dataKeyLimits: const {
        'clock': DataKeyProgramLimit(minPlacementsPerProgram: 2),
      },
    );
    final clockCount = slides.where((s) => s.screenId.startsWith('clock_')).length;
    expect(clockCount, greaterThanOrEqualTo(2));
  });

  test('pexels widgets resolve pool names with optional categoryId', () {
    final layoutPhoto = jsonEncode({
      'v': 1,
      'layout': 'single',
      'widgets': [
        {
          'type': 'pexels_photo',
          'slot': 'main',
          'config': {'categoryId': 'nature'},
        },
      ],
    });
    final layoutVideo = jsonEncode({
      'v': 1,
      'layout': 'single',
      'widgets': [
        {'type': 'pexels_video', 'slot': 'main', 'config': {}},
      ],
    });
    final photoSlides = ScreenProgramCurator.buildProgram(
      screens: [_c(id: 'p', dwellMs: 60000, layout: layoutPhoto)],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'pexels_photo:nature': ['a1']},
    );
    expect(photoSlides.single.randomChoices['main_pexels_photo'], 'a1');

    final videoSlides = ScreenProgramCurator.buildProgram(
      screens: [_c(id: 'v', dwellMs: 60000, layout: layoutVideo)],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'pexels_video': ['v1']},
    );
    expect(videoSlides.single.randomChoices['main_pexels_video'], 'v1');
  });

  test('joint metrics path can rotate among multiple rss news screen definitions', () {
    const layout =
        '{"v":1,"widgets":[{"type":"rss_article","slot":"main","config":{"summaryCapacityChars":500}}]}';
    final seenIds = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      final slides = ScreenProgramCurator.buildProgram(
        screens: [
          _c(id: 'news_a', dwellMs: 30000, layout: layout),
          _c(id: 'news_b', dwellMs: 30000, layout: layout),
        ],
        programDurationMs: 60000,
        recentScreenIdsOldestFirst: const [],
        historyDepth: 5,
        random: Random(seed),
        randomPools: const {
          'rss': ['a1', 'a2', 'a3', 'a4'],
        },
        rssArticleMetrics: const {
          'a1': RssArticleMetric(
            hasImage: true,
            summaryLength: 200,
            categoryId: 'general',
          ),
          'a2': RssArticleMetric(
            hasImage: true,
            summaryLength: 200,
            categoryId: 'general',
          ),
          'a3': RssArticleMetric(
            hasImage: true,
            summaryLength: 200,
            categoryId: 'general',
          ),
          'a4': RssArticleMetric(
            hasImage: true,
            summaryLength: 200,
            categoryId: 'general',
          ),
        },
        requirePhotoForRssScreens: true,
      );
      expect(slides, hasLength(2));
      seenIds.add(slides[0].screenId);
      seenIds.add(slides[1].screenId);
    }
    expect(seenIds.contains('news_a'), isTrue);
    expect(seenIds.contains('news_b'), isTrue);
  });

  test('joint best-fit prefers news screen whose capacity fits summary length', () {
    const layoutBig =
        '{"v":1,"widgets":[{"type":"rss_article","slot":"main","config":{"summaryCapacityChars":1200}}]}';
    const layoutSmall =
        '{"v":1,"widgets":[{"type":"rss_article","slot":"main","config":{"summaryCapacityChars":100}}]}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'news_big', dwellMs: 60000, layout: layoutBig),
        _c(id: 'news_small', dwellMs: 60000, layout: layoutSmall),
      ],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'rss': ['a1']},
      rssArticleMetrics: const {
        'a1': RssArticleMetric(
          hasImage: true,
          summaryLength: 500,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides, hasLength(1));
    expect(slides.single.screenId, 'news_big');
    expect(slides.single.randomChoices['main_rss_article'], 'a1');
  });

  test('requirePhoto skips photoless rss when min placements satisfied', () {
    const layout =
        '{"v":1,"widgets":[{"type":"rss_article","slot":"main","config":{}}]}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(id: 'rss_only', dwellMs: 60000, layout: layout),
      ],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'rss': ['n1']},
      rssArticleMetrics: const {
        'n1': RssArticleMetric(
          hasImage: false,
          summaryLength: 10,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides, isEmpty);
  });

  test('min-placement fallback uses photoless article and imageMode icon', () {
    const layout =
        '{"v":1,"widgets":[{"type":"rss_article","slot":"main","config":{}}]}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        _c(
          id: 'rss_must',
          dwellMs: 60000,
          layout: layout,
          minPlacementsPerProgram: 1,
        ),
      ],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'rss': ['n1']},
      rssArticleMetrics: const {
        'n1': RssArticleMetric(
          hasImage: false,
          summaryLength: 10,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides, hasLength(1));
    expect(slides.single.randomChoices['main_rss_article'], 'n1');
    expect(slides.single.randomChoices['main_rss_article_imageMode'], 'icon');
  });

  test('rss_article_columns picks one category for global rss pool', () {
    const layout = '{"v":1,"layout":"single","widgets":['
        '{"type":"rss_article_columns","slot":"main","config":{"columnCount":3}}'
        ']}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [_c(id: 'nc', dwellMs: 30000, layout: layout)],
      programDurationMs: 30000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(7),
      randomPools: {
        'rss': ['w1', 'w2', 'w3', 'u1', 'u2'],
      },
      rssArticleMetrics: const {
        'w1': RssArticleMetric(
          hasImage: true,
          summaryLength: 80,
          categoryId: 'world',
        ),
        'w2': RssArticleMetric(
          hasImage: true,
          summaryLength: 80,
          categoryId: 'world',
        ),
        'w3': RssArticleMetric(
          hasImage: true,
          summaryLength: 80,
          categoryId: 'world',
        ),
        'u1': RssArticleMetric(
          hasImage: true,
          summaryLength: 80,
          categoryId: 'usa',
        ),
        'u2': RssArticleMetric(
          hasImage: true,
          summaryLength: 80,
          categoryId: 'usa',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides, hasLength(1));
    final m = slides.single.randomChoices;
    final screenCat = m[ScreenProgramCurator.rssScreenCategoryChoiceKey];
    expect(screenCat, isIn(['world', 'usa']));
    const metrics = {
      'w1': RssArticleMetric(
        hasImage: true,
        summaryLength: 80,
        categoryId: 'world',
      ),
      'w2': RssArticleMetric(
        hasImage: true,
        summaryLength: 80,
        categoryId: 'world',
      ),
      'w3': RssArticleMetric(
        hasImage: true,
        summaryLength: 80,
        categoryId: 'world',
      ),
      'u1': RssArticleMetric(
        hasImage: true,
        summaryLength: 80,
        categoryId: 'usa',
      ),
      'u2': RssArticleMetric(
        hasImage: true,
        summaryLength: 80,
        categoryId: 'usa',
      ),
    };
    for (var i = 0; i < 3; i++) {
      final id = m['main_rss_article_columns_$i']!;
      expect(metrics[id]!.categoryId, screenCat);
    }
    expect(
      m['main_rss_article_columns_0'] != m['main_rss_article_columns_1'],
      isTrue,
    );
  });

  test('rss categoryId config sets screen category and uses rss_category pool', () {
    const layout = '{"v":1,"layout":"single","widgets":['
        '{"type":"rss_article","slot":"main","config":{"categoryId":"technology"}}'
        ']}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [_c(id: 'n', dwellMs: 30000, layout: layout)],
      programDurationMs: 30000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(1),
      randomPools: {
        'rss_category:technology': ['t1'],
      },
      rssArticleMetrics: const {
        't1': RssArticleMetric(
          hasImage: true,
          summaryLength: 200,
          categoryId: 'technology',
        ),
      },
    );
    expect(slides.single.randomChoices['main_rss_article'], 't1');
    expect(
      slides.single.randomChoices[ScreenProgramCurator.rssScreenCategoryChoiceKey],
      'technology',
    );
  });
}
