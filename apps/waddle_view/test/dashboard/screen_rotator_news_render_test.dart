import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/screen_rotator.dart';

void main() {
  final candidates = <ScreenCandidate>[
    const ScreenCandidate(
      id: 'news',
      dwellMs: 60000,
      frequencyWeight: 100,
      minGapBetweenShowsMs: 0,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"rss_article","slot":"main","config":{}}]}',
      enabled: true,
    ),
    const ScreenCandidate(
      id: 'welcome',
      dwellMs: 10000,
      frequencyWeight: 100,
      minGapBetweenShowsMs: 0,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"static_text","slot":"main","config":{"text":"hello"}}]}',
      enabled: true,
    ),
  ];

  test('news is excluded when photo is required but unavailable', () {
    final filtered = filterNewsCandidatesByPhotoRequirement(
      candidates: candidates,
      requirePhotoForNewsCuration: true,
      hasNewsPhotoData: false,
    );

    expect(filtered.map((c) => c.id), equals(['welcome']));
  });

  test('news remains when photo requirement is disabled', () {
    final filtered = filterNewsCandidatesByPhotoRequirement(
      candidates: candidates,
      requirePhotoForNewsCuration: false,
      hasNewsPhotoData: false,
    );

    expect(filtered.map((c) => c.id), equals(['news', 'welcome']));
  });

  test('news remains when photo data exists', () {
    final filtered = filterNewsCandidatesByPhotoRequirement(
      candidates: candidates,
      requirePhotoForNewsCuration: true,
      hasNewsPhotoData: true,
    );

    expect(filtered.map((c) => c.id), equals(['news', 'welcome']));
  });
}
