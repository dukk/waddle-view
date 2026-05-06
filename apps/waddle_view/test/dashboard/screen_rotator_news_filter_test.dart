import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/screen_rotator.dart';

ScreenCandidate _c(String id, String layoutJson) => ScreenCandidate(
      id: id,
      dwellMs: 5000,
      frequencyWeight: 100,
      minGapBetweenShowsMs: 0,
      layoutJson: layoutJson,
      enabled: true,
    );

void main() {
  test('filterNewsCandidatesByPhotoRequirement keeps all when flag off', () {
    const rssLayout =
        '{"v":1,"widgets":[{"type":"rss_article","slot":"a","config":{}}]}';
    final candidates = [
      _c('a', rssLayout),
      _c('b', '{"v":1,"widgets":[{"type":"digital_clock","slot":"m","config":{}}]}'),
    ];
    final out = filterNewsCandidatesByPhotoRequirement(
      candidates: candidates,
      requirePhotoForNewsCuration: false,
      hasNewsPhotoData: false,
    );
    expect(out.map((e) => e.id).toList(), ['a', 'b']);
  });

  test('filterNewsCandidatesByPhotoRequirement keeps all when photo data exists',
      () {
    const rssLayout =
        '{"v":1,"widgets":[{"type":"rss_article_columns","slot":"a","config":{}}]}';
    final candidates = [_c('n', rssLayout)];
    final out = filterNewsCandidatesByPhotoRequirement(
      candidates: candidates,
      requirePhotoForNewsCuration: true,
      hasNewsPhotoData: true,
    );
    expect(out.single.id, 'n');
  });

  test(
    'filterNewsCandidatesByPhotoRequirement drops rss layouts when required '
    'and no photo rows',
    () {
      const rss =
          '{"v":1,"widgets":[{"type":"rss_article","slot":"x","config":{}}]}';
      const cols =
          '{"v":1,"widgets":[{"type":"rss_article_columns","slot":"y","config":{}}]}';
      final candidates = [
        _c('news1', rss),
        _c('clock', '{"v":1,"widgets":[{"type":"digital_clock","slot":"m","config":{}}]}'),
        _c('news2', cols),
      ];
      final out = filterNewsCandidatesByPhotoRequirement(
        candidates: candidates,
        requirePhotoForNewsCuration: true,
        hasNewsPhotoData: false,
      );
      expect(out.map((e) => e.id).toList(), ['clock']);
    },
  );

  test('screenShownDebugLogLine includes reason and layout', () {
    final line = screenShownDebugLogLine(
      reason: 'program_start',
      slideIndex: 0,
      totalSlides: 3,
      screenId: 'scr',
      dwellMs: 12000,
      layoutJson: '{"v":1}',
      randomChoices: const {'k': 'v'},
    );
    expect(line, contains('reason=program_start'));
    expect(line, contains('index=0/3'));
    expect(line, contains('screenId=scr'));
    expect(line, contains('dwellMs=12000'));
    expect(line, contains('layout={"v":1}'));
    expect(line, contains('randomChoices={k: v}'));
  });
}
