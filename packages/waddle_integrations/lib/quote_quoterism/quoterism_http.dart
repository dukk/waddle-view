import 'package:http/http.dart' as http;
import 'package:waddle_shared/net/http_debug_uri.dart';

const String kQuoterismDefaultBaseUrl = 'https://www.quoterism.com';
const Duration kQuoterismHttpTimeout = Duration(seconds: 30);
const String kQuoterismApiKeyHeader = 'X-API-Key';

String normalizeQuoterismBaseUrl(String? baseUrl) {
  final raw = (baseUrl ?? kQuoterismDefaultBaseUrl).trim();
  if (raw.isEmpty) {
    return kQuoterismDefaultBaseUrl;
  }
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

/// Builds a GET [Uri] (pass [quoterismRequestHeaders] to [http.Client.get]).
Uri buildQuoterismGetUri({
  required String baseUrl,
  required String path,
  Map<String, String>? query,
}) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return Uri.parse('$baseUrl$normalizedPath').replace(
    queryParameters: query,
  );
}

Map<String, String> quoterismRequestHeaders(String apiKey) => {
      kQuoterismApiKeyHeader: apiKey,
      'Accept': 'application/json',
    };

String safeQuoterismUriForLog(Uri uri) => safeHttpUriForLog(uri);
