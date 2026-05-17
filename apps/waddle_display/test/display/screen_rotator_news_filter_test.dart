import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/curator_content_pools.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';

/// Photo gating for RSS screen slides is enforced by [ScreenProgramCurator]
/// ([rssArticleMetrics], [requirePhotoForRssScreens]); the ticker is unchanged.
void main() {
  test('photo requirement drops rss-only program when no images available', () {
    const layout =
        '{"v":1,"widgets":[{"type":"news","slot":"main","config":{}}]}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        const ScreenCandidate(
          id: 'rss_only',
          minDwellMs: 60000,
          maxDwellMs: 60000,
          frequencyWeight: 100,
          minGapBetweenShowsMs: 0,
          layoutJson: layout,
        ),
      ],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(1),
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
    expect(slides, isEmpty);
  });

  test('rss slide plays when article has image under requirePhoto', () {
    const layout =
        '{"v":1,"widgets":[{"type":"news","slot":"main","config":{}}]}';
    final slides = ScreenProgramCurator.buildProgram(
      screens: [
        const ScreenCandidate(
          id: 'rss_only',
          minDwellMs: 60000,
          maxDwellMs: 60000,
          frequencyWeight: 100,
          minGapBetweenShowsMs: 0,
          layoutJson: layout,
        ),
      ],
      programDurationMs: 60000,
      recentScreenIdsOldestFirst: const [],
      historyDepth: 5,
      random: Random(1),
      randomPools: const {'rss': ['x']},
      rssArticleMetrics: const {
        'x': RssArticleMetric(
          hasImage: true,
          summaryLength: 5,
          categoryId: 'general',
        ),
      },
      requirePhotoForRssScreens: true,
    );
    expect(slides, hasLength(1));
    expect(slides.single.randomChoices['main_news'], 'x');
  });
}
