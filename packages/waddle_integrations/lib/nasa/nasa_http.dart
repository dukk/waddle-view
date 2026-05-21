import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/collect_diagnostics.dart';

const String kDefaultNasaApiBaseUrl = 'https://api.nasa.gov';

const Duration kNasaHttpTimeout = Duration(seconds: 15);

String normalizeNasaBaseUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return kDefaultNasaApiBaseUrl;
  }
  return raw.trim().replaceAll(RegExp(r'/$'), '');
}

/// Builds a NASA API URI with [apiKey] as `api_key` query parameter.
Uri buildNasaApiUri({
  required String baseUrl,
  required String path,
  required String apiKey,
  Map<String, String> query = const {},
}) {
  final base = normalizeNasaBaseUrl(baseUrl);
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  final params = <String, String>{...query, 'api_key': apiKey};
  return Uri.parse('$base$normalizedPath').replace(queryParameters: params);
}

void logNasaRateLimitHeaders(CollectDiagnostics diagnostics, http.Response res) {
  final limit = res.headers['x-ratelimit-limit'];
  final remaining = res.headers['x-ratelimit-remaining'];
  if (limit == null && remaining == null) {
    return;
  }
  diagnostics.provider(
    'nasa: rate limit remaining=$remaining limit=$limit',
  );
}

String truncateAltText(String text, {int maxLen = 500}) {
  final t = text.trim();
  if (t.length <= maxLen) {
    return t;
  }
  return '${t.substring(0, maxLen - 1)}…';
}

String apodPageUrlForDate(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length != 3) {
    return 'https://apod.nasa.gov/apod/astropix.html';
  }
  final yy = parts[0].length >= 4 ? parts[0].substring(2) : parts[0];
  final mm = parts[1].padLeft(2, '0');
  final dd = parts[2].padLeft(2, '0');
  return 'https://apod.nasa.gov/apod/ap$yy$mm$dd.html';
}

String formatUtcDate(DateTime utc) {
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String earthAssetDateFromIso(String iso) {
  if (iso.length >= 10) {
    return iso.substring(0, 10);
  }
  return iso;
}
