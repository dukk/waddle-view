import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/curator_content_pools.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';

/// Mirrors former candidate-filter tests: without usable RSS photos, non-news
/// screens still receive placements when eligible.
void main() {
  final candidates = <ScreenCandidate>[
    const ScreenCandidate(
      id: 'news',
      minDwellMs: 60000,
      maxDwellMs: 60000,
      frequencyWeight: 100,
      minGapBetweenShowsMs: 0,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"news","slot":"main","config":{}}]}',
    ),
    const ScreenCandidate(
      id: 'welcome',
      minDwellMs: 10000,
      maxDwellMs: 10000,
      frequencyWeight: 100,
      minGapBetweenShowsMs: 0,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"static_text","slot":"main","config":{"text":"hello"}}]}',
    ),
  ];

  test('welcome still plays when rss articles lack photos for screen slides', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: candidates,
      programDurationMs: 70000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'rss': ['x']},
      rssArticleMetrics: const {
        'x': RssArticleMetric(
          hasImage: false,
          summaryLength: 10,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides.isNotEmpty, isTrue);
    expect(slides.every((s) => s.screenId == 'welcome'), isTrue);
  });

  test('news slide resolves when rss article has image', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [candidates[0]],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'rss': ['x']},
      rssArticleMetrics: const {
        'x': RssArticleMetric(
          hasImage: true,
          summaryLength: 10,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides.single.screenId, 'news');
    expect(slides.single.randomChoices['main_news'], 'x');
  });

  test('news slide resolves without images when requirePhoto disabled', () {
    final slides = ScreenProgramCurator.buildProgram(
      screens: [candidates[0]],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'rss': ['x']},
      rssArticleMetrics: const {
        'x': RssArticleMetric(
          hasImage: false,
          summaryLength: 10,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: false,
    );
    expect(slides.single.screenId, 'news');
  });

  test('news_stack excluded when photos required but unavailable', () {
    final withStack = <ScreenCandidate>[
      const ScreenCandidate(
        id: 'news_stack',
        minDwellMs: 60000,
        maxDwellMs: 60000,
        frequencyWeight: 100,
        minGapBetweenShowsMs: 0,
        layoutJson:
            '{"v":1,"layout":"single","widgets":[{"type":"news_stack","slot":"main","config":{}}]}',
      ),
      candidates[1],
    ];
    final slides = ScreenProgramCurator.buildProgram(
      screens: withStack,
      programDurationMs: 70000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(0),
      randomPools: const {'rss': ['x', 'y']},
      rssArticleMetrics: const {
        'x': RssArticleMetric(
          hasImage: false,
          summaryLength: 10,
          categoryId: 'general',
        ),
        'y': RssArticleMetric(
          hasImage: false,
          summaryLength: 10,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides.every((s) => s.screenId == 'welcome'), isTrue);
  });
}
