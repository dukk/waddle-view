import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:waddle_shared/news/social_news_post.dart';

const String kLinkedInRestApiBase = 'https://api.linkedin.com/rest';
const String kLinkedInRestVersion = '202401';

List<SocialNewsPost> parseLinkedInPostsJson(String body) {
  final root = jsonDecode(body) as Map<String, dynamic>;
  final elements = root['elements'];
  if (elements is! List<dynamic>) {
    return const [];
  }
  final out = <SocialNewsPost>[];
  for (final raw in elements) {
    if (raw is! Map<String, dynamic>) {
      continue;
    }
    final id = '${raw['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      continue;
    }
    final commentary = raw['commentary'];
    var text = '';
    if (commentary is String) {
      text = commentary.trim();
    } else if (commentary is Map<String, dynamic>) {
      text = '${commentary['text'] ?? ''}'.trim();
    }
    final createdRaw = raw['createdAt'];
    final createdMs = createdRaw is num
        ? createdRaw.toInt()
        : int.tryParse('$createdRaw');
    if (createdMs == null) {
      continue;
    }
    final link = _permalinkForPostId(id);
    out.add(
      SocialNewsPost(
        id: id,
        text: text.isEmpty ? link : text,
        link: link,
        createdAtMs: createdMs,
      ),
    );
  }
  return out;
}

String _permalinkForPostId(String postId) {
  final encoded = Uri.encodeComponent(postId);
  return 'https://www.linkedin.com/feed/update/$encoded';
}

String linkedInAuthorUrn(String targetType, String targetId) {
  final id = targetId.trim();
  if (targetType == 'member') {
    return id.startsWith('urn:li:person:') ? id : 'urn:li:person:$id';
  }
  return id.startsWith('urn:li:organization:')
      ? id
      : 'urn:li:organization:$id';
}

class LinkedInApiClient {
  LinkedInApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<List<SocialNewsPost>> fetchAuthorPosts({
    required String accessToken,
    required String targetType,
    required String targetId,
    void Function(String message)? log,
  }) async {
    final author = linkedInAuthorUrn(targetType, targetId);
    final uri = Uri.parse('$kLinkedInRestApiBase/posts').replace(
      queryParameters: {
        'q': 'author',
        'author': author,
        'count': '25',
      },
    );
    log?.call('linkedin: GET ${safeHttpUriForLog(uri)}');
    final res = await _http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'LinkedIn-Version': kLinkedInRestVersion,
        'X-Restli-Protocol-Version': '2.0.0',
      },
    );
    if (res.statusCode != 200) {
      log?.call(
        'linkedin: posts status=${res.statusCode} author=$author',
      );
      return const [];
    }
    return parseLinkedInPostsJson(res.body);
  }
}
