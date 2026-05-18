import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/net/http_debug_uri.dart';

const String kFacebookGraphApiBase = 'https://graph.facebook.com/v21.0';

/// One post from a Facebook page or group feed.
class FacebookFeedPost {
  const FacebookFeedPost({
    required this.id,
    required this.message,
    required this.permalinkUrl,
    required this.createdAtMs,
    this.fullPictureUrl,
  });

  final String id;
  final String message;
  final String permalinkUrl;
  final int createdAtMs;
  final String? fullPictureUrl;
}

List<FacebookFeedPost> parseFacebookFeedPostsJson(String body) {
  final root = jsonDecode(body) as Map<String, dynamic>;
  final data = root['data'];
  if (data is! List<dynamic>) {
    return const [];
  }
  final out = <FacebookFeedPost>[];
  for (final raw in data) {
    if (raw is! Map<String, dynamic>) {
      continue;
    }
    final id = '${raw['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      continue;
    }
    final message = '${raw['message'] ?? ''}'.trim();
    final link = '${raw['permalink_url'] ?? ''}'.trim();
    final createdRaw = raw['created_time'];
    final createdMs = _parseFacebookTimeMs(createdRaw);
    if (createdMs == null) {
      continue;
    }
    final picture = '${raw['full_picture'] ?? ''}'.trim();
    out.add(
      FacebookFeedPost(
        id: id,
        message: message.isEmpty ? link : message,
        permalinkUrl: link.isEmpty ? 'https://www.facebook.com/$id' : link,
        createdAtMs: createdMs,
        fullPictureUrl: picture.isEmpty ? null : picture,
      ),
    );
  }
  return out;
}

int? _parseFacebookTimeMs(Object? raw) {
  if (raw == null) {
    return null;
  }
  final s = '$raw'.trim();
  if (s.isEmpty) {
    return null;
  }
  final dt = DateTime.tryParse(s);
  return dt?.toUtc().millisecondsSinceEpoch;
}

class FacebookGraphClient {
  FacebookGraphClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<List<FacebookFeedPost>> fetchPageOrGroupPosts({
    required String accessToken,
    required String targetType,
    required String targetId,
    void Function(String message)? log,
  }) async {
    final path = targetType == 'group'
        ? '$targetId/feed'
        : '$targetId/posts';
    final uri = Uri.parse(
      '$kFacebookGraphApiBase/$path',
    ).replace(
      queryParameters: {
        'fields': 'id,message,created_time,permalink_url,full_picture',
        'limit': '25',
        'access_token': accessToken,
      },
    );
    log?.call('facebook: GET ${safeHttpUriForLog(uri)}');
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      log?.call(
        'facebook: feed status=${res.statusCode} target=$targetId '
        'type=$targetType',
      );
      return const [];
    }
    return parseFacebookFeedPostsJson(res.body);
  }
}
