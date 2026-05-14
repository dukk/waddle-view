import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database_stats_repository.dart';

import 'package:waddle_display/display/screens/data_health/data_health_metrics.dart';

DatabaseHealthSnapshot _snap({
  List<CategoryStat> photosByCategory = const [],
  List<CategoryStat> videosByCategory = const [],
}) {
  return DatabaseHealthSnapshot(
    collectedAt: DateTime.utc(2024, 1, 1),
    rssArticleTotal: 0,
    rssArticleActive: 0,
    rssArticleSuppressed: 0,
    rssArticlesWithImage: 0,
    rssArticlesWithoutImage: 0,
    rssFeedsEnabled: 0,
    rssFeedsDisabled: 0,
    rssFeedsWithConsecutiveFailures: 0,
    photoTotal: 0,
    photoActive: 0,
    photoSuppressed: 0,
    videoTotal: 0,
    videoActive: 0,
    videoSuppressed: 0,
    jokeTotal: 0,
    jokeActive: 0,
    jokeSuppressed: 0,
    triviaTotal: 0,
    triviaActive: 0,
    triviaSuppressed: 0,
    calendarEventCount: 0,
    blobRowCount: 0,
    blobTotalBytes: 0,
    rssByCategory: const [],
    photosByCategory: photosByCategory,
    videosByCategory: videosByCategory,
    jokesByCategory: const [],
    triviaByCategory: const [],
  );
}

void main() {
  group('parseDataHealthRefreshSeconds', () {
    test('defaults and clamps', () {
      expect(parseDataHealthRefreshSeconds({}), 45);
      expect(parseDataHealthRefreshSeconds({'refreshIntervalSeconds': 10}), 15);
      expect(parseDataHealthRefreshSeconds({'refreshIntervalSeconds': 400}), 300);
      expect(parseDataHealthRefreshSeconds({'refreshIntervalSeconds': 90}), 90);
      expect(parseDataHealthRefreshSeconds({'refreshIntervalSeconds': 12.7}), 15);
    });
  });

  group('formatDataHealthBytes', () {
    test('units', () {
      expect(formatDataHealthBytes(0), '0 B');
      expect(formatDataHealthBytes(1023), '1023 B');
      expect(formatDataHealthBytes(1024), '1.0 KB');
      expect(formatDataHealthBytes(2048), '2.0 KB');
      expect(formatDataHealthBytes(1024 * 1024), '1.00 MB');
      expect(formatDataHealthBytes(3 * 1024 * 1024), '3.00 MB');
    });
  });

  group('formatDataHealthTime', () {
    test('pads components', () {
      expect(
        formatDataHealthTime(DateTime(2024, 1, 2, 3, 4, 5)),
        '03:04:05',
      );
    });
  });

  group('mergePhotosVideosForChart', () {
    test('merges labels and sorts by total', () {
      final out = mergePhotosVideosForChart(
        _snap(
          photosByCategory: const [
            CategoryStat(categoryId: 'a', label: 'A', count: 2),
            CategoryStat(categoryId: 'b', label: 'B', count: 1),
          ],
          videosByCategory: const [
            CategoryStat(categoryId: 'b', label: 'B', count: 4),
          ],
        ),
      );
      expect(out.map((e) => e.label).toList(), ['B', 'A']);
      expect(out[0].photos, 1);
      expect(out[0].videos, 4);
      expect(out[1].photos, 2);
      expect(out[1].videos, 0);
    });

    test('replaces slug label with video label when ids match', () {
      final out = mergePhotosVideosForChart(
        _snap(
          photosByCategory: const [
            CategoryStat(categoryId: 'news', label: 'news', count: 1),
          ],
          videosByCategory: const [
            CategoryStat(categoryId: 'news', label: 'News desk', count: 1),
          ],
        ),
      );
      expect(out.single.label, 'News desk');
    });

    test('folds overflow into Other', () {
      final photos = List.generate(
        10,
        (i) => CategoryStat(
          categoryId: 'c$i',
          label: 'C$i',
          count: 1,
        ),
      );
      final out = mergePhotosVideosForChart(
        _snap(photosByCategory: photos),
        limit: 4,
      );
      expect(out.length, 4);
      expect(out.last.label, 'Other');
      expect(out.last.photos, 7);
      expect(out.last.videos, 0);
    });
  });
}
