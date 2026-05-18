import 'package:test/test.dart';
import 'package:waddle_data_providers/news_twitter/twitter_api_client.dart';

void main() {
  test('parseTwitterTweetsJson maps tweets', () {
    const body = '''
{
  "data": [
    {
      "id": "123",
      "text": "Hello X",
      "created_at": "2024-01-15T12:00:00.000Z"
    }
  ]
}
''';
    final posts = parseTwitterTweetsJson(body, 'user1');
    expect(posts, hasLength(1));
    expect(posts.single.id, '123');
    expect(posts.single.text, 'Hello X');
    expect(posts.single.link, contains('123'));
  });
}
