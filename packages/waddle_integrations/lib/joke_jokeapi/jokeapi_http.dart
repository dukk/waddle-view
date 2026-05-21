import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/collect_diagnostics.dart';

const String kDefaultJokeApiBaseUrl = 'https://v2.jokeapi.dev/joke';

const String kJokeApiRateLimitUntilKey = 'jokeapi.rate_limit_until_ms';

const Duration kJokeApiHttpTimeout = Duration(seconds: 15);

const String kJokeApiUserAgent = 'waddle-view/joke_jokeapi';

/// Default backoff when [Retry-After] is missing on HTTP 429.
const int kJokeApi429FallbackSeconds = 60;

String normalizeJokeApiBaseUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return kDefaultJokeApiBaseUrl;
  }
  var base = raw.trim().replaceAll(RegExp(r'/$'), '');
  if (base.endsWith('/joke')) {
    return base;
  }
  if (base.endsWith('/v2')) {
    return '$base/joke';
  }
  return base;
}

Uri buildJokeApiUri({
  required String baseUrl,
  required String apiCategory,
  required int amount,
  required List<String> blacklistFlags,
  String? contains,
}) {
  final base = normalizeJokeApiBaseUrl(baseUrl);
  final encodedCategory = Uri.encodeComponent(apiCategory);
  final query = <String, String>{
    'type': 'twopart',
    'amount': '$amount',
  };
  if (blacklistFlags.isNotEmpty) {
    query['blacklistFlags'] = blacklistFlags.join(',');
  }
  if (contains != null && contains.isNotEmpty) {
    query['contains'] = contains;
  }
  return Uri.parse('$base/$encodedCategory').replace(queryParameters: query);
}

void logJokeApiRateLimitHeaders(CollectDiagnostics diagnostics, http.Response res) {
  final limit = res.headers['ratelimit-limit'];
  final remaining = res.headers['ratelimit-remaining'];
  if (limit == null && remaining == null) {
    return;
  }
  diagnostics.provider(
    'joke_jokeapi: rate limit remaining=$remaining limit=$limit',
  );
}

/// Milliseconds since epoch when requests may resume, or null if no backoff needed.
int? jokeApiRateLimitUntilMsFromResponse(http.Response res, int nowMs) {
  if (res.statusCode == 429) {
    return nowMs + _retryAfterMs(res.headers['retry-after'], kJokeApi429FallbackSeconds);
  }
  final remaining = int.tryParse(res.headers['ratelimit-remaining'] ?? '');
  if (remaining != null && remaining <= 0) {
    final resetMs = _rateLimitResetMs(res.headers['ratelimit-reset'], nowMs);
    if (resetMs != null && resetMs > nowMs) {
      return resetMs;
    }
    return nowMs + kJokeApi429FallbackSeconds * 1000;
  }
  return null;
}

int _retryAfterMs(String? raw, int fallbackSeconds) {
  if (raw == null || raw.trim().isEmpty) {
    return fallbackSeconds * 1000;
  }
  final trimmed = raw.trim();
  final seconds = int.tryParse(trimmed);
  if (seconds != null && seconds >= 0) {
    return seconds * 1000;
  }
  final parsed = _parseHttpDateMs(trimmed);
  if (parsed != null) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = parsed - now;
    return delta > 0 ? delta : fallbackSeconds * 1000;
  }
  return fallbackSeconds * 1000;
}

int? _rateLimitResetMs(String? raw, int nowMs) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return _parseHttpDateMs(raw.trim());
}

int? _parseHttpDateMs(String value) {
  try {
    final dt = HttpDate.parse(value);
    return dt.millisecondsSinceEpoch;
  } on Object {
    return null;
  }
}
