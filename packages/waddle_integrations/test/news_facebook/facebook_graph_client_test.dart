import 'package:test/test.dart';
import 'package:waddle_data_providers/news_facebook/facebook_graph_client.dart';

void main() {
  test('parseFacebookFeedPostsJson maps posts', () {
    const body = '''
{
  "data": [
    {
      "id": "123_456",
      "message": "Hello world",
      "created_time": "2024-01-15T12:00:00+0000",
      "permalink_url": "https://www.facebook.com/post/1",
      "full_picture": "https://cdn.example.com/pic.jpg"
    }
  ]
}
''';
    final posts = parseFacebookFeedPostsJson(body);
    expect(posts, hasLength(1));
    expect(posts.single.id, '123_456');
    expect(posts.single.message, 'Hello world');
    expect(posts.single.permalinkUrl, 'https://www.facebook.com/post/1');
    expect(posts.single.fullPictureUrl, 'https://cdn.example.com/pic.jpg');
    expect(posts.single.createdAtMs, greaterThan(0));
  });
}
