import 'package:test/test.dart';
import 'package:waddle_data_providers/news_linkedin/linkedin_api_client.dart';

void main() {
  test('parseLinkedInPostsJson maps posts', () {
    const body = '''
{
  "elements": [
    {
      "id": "urn:li:share:999",
      "commentary": "Company update",
      "createdAt": 1700000000000
    }
  ]
}
''';
    final posts = parseLinkedInPostsJson(body);
    expect(posts, hasLength(1));
    expect(posts.single.id, 'urn:li:share:999');
    expect(posts.single.text, 'Company update');
  });

  test('linkedInAuthorUrn builds organization urn', () {
    expect(
      linkedInAuthorUrn('organization', '12345'),
      'urn:li:organization:12345',
    );
  });
}
