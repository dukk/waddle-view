import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/news/social_news_collect.dart';

void main() {
  group('socialNewsTitleFromText', () {
    test('uses fallback when text empty', () {
      expect(
        socialNewsTitleFromText('   ', fallback: 'Post'),
        'Post',
      );
    });

    test('truncates long text with ellipsis', () {
      final long = 'a' * 250;
      final title = socialNewsTitleFromText(long, fallback: 'Post');
      expect(title.length, 200);
      expect(title.endsWith('…'), isTrue);
    });

    test('returns trimmed text when within limit', () {
      expect(
        socialNewsTitleFromText('  Hello world  ', fallback: 'Post'),
        'Hello world',
      );
    });
  });
}
