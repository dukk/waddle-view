import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:waddle_shared/news/social_news_post.dart';

const String kTwitterApiBase = 'https://api.twitter.com/2';

List<SocialNewsPost> parseTwitterTweetsJson(String body, String userId) {
  final root = jsonDecode(body) as Map<String, dynamic>;
  final data = root['data'];
  if (data is! List<dynamic>) {
    return const [];
  }
  final includes = root['includes'];
  final mediaByKey = <String, Map<String, dynamic>>{};
  if (includes is Map<String, dynamic>) {
    final media = includes['media'];
    if (media is List<dynamic>) {
      for (final m in media) {
        if (m is Map<String, dynamic>) {
          final key = '${m['media_key'] ?? ''}'.trim();
          if (key.isNotEmpty) {
            mediaByKey[key] = m;
          }
        }
      }
    }
  }

  final out = <SocialNewsPost>[];
  for (final raw in data) {
    if (raw is! Map<String, dynamic>) {
      continue;
    }
    final id = '${raw['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      continue;
    }
    final text = '${raw['text'] ?? ''}'.trim();
    final createdRaw = raw['created_at'];
    final createdMs = _parseIsoTimeMs(createdRaw);
    if (createdMs == null) {
      continue;
    }
    String? imageUrl;
    final attachments = raw['attachments'];
    if (attachments is Map<String, dynamic>) {
      final keys = attachments['media_keys'];
      if (keys is List<dynamic> && keys.isNotEmpty) {
        final mediaKey = '${keys.first}'.trim();
        final media = mediaByKey[mediaKey];
        final url = media == null
            ? null
            : '${media['url'] ?? media['preview_image_url'] ?? ''}'.trim();
        if (url != null && url.isNotEmpty) {
          imageUrl = url;
        }
      }
    }
    out.add(
      SocialNewsPost(
        id: id,
        text: text,
        link: 'https://x.com/i/web/status/$id',
        createdAtMs: createdMs,
        imageUrl: imageUrl,
      ),
    );
  }
  return out;
}

int? _parseIsoTimeMs(Object? raw) {
  if (raw == null) {
    return null;
  }
  final s = '$raw'.trim();
  if (s.isEmpty) {
    return null;
  }
  return DateTime.tryParse(s)?.toUtc().millisecondsSinceEpoch;
}

class TwitterApiClient {
  TwitterApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<List<SocialNewsPost>> fetchUserTweets({
    required String bearerToken,
    required String userId,
    void Function(String message)? log,
  }) async {
    final uri = Uri.parse('$kTwitterApiBase/users/$userId/tweets').replace(
      queryParameters: {
        'max_results': '25',
        'tweet.fields': 'created_at,text,attachments',
        'expansions': 'attachments.media_keys',
        'media.fields': 'url,preview_image_url',
      },
    );
    log?.call('twitter: GET ${safeHttpUriForLog(uri)}');
    final res = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer $bearerToken'},
    );
    if (res.statusCode != 200) {
      log?.call('twitter: tweets status=${res.statusCode} user=$userId');
      return const [];
    }
    return parseTwitterTweetsJson(res.body, userId);
  }
}
