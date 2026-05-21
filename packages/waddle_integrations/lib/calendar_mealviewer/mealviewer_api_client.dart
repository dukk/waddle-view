import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/mealviewer_kv.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';

import '../news_rss/rss_http_response_body_decode.dart';
import 'mealviewer_calendar_extra_config.dart';

/// Summary row for operator school search / district browse.
class MealviewerSchoolSummary {
  const MealviewerSchoolSummary({
    required this.schoolSlug,
    required this.label,
    this.city,
    this.state,
    this.districtSlug,
  });

  final String schoolSlug;
  final String label;
  final String? city;
  final String? state;
  final String? districtSlug;

  static MealviewerSchoolSummary? fromPhysicalLocationJson(
    Map<String, dynamic> raw,
  ) {
    final slug = normalizeMealviewerSchoolSlug(
      raw['physicalLocationLookup'] as String?,
    );
    if (slug == null) {
      return null;
    }
    final name = (raw['name'] as String?)?.trim();
    final label = name != null && name.isNotEmpty ? name : slug;
    final city = (raw['city'] as String?)?.trim();
    final state = (raw['state'] as String?)?.trim();
    final district = (raw['districtLookup'] as String?)?.trim();
    return MealviewerSchoolSummary(
      schoolSlug: slug,
      label: label,
      city: city != null && city.isNotEmpty ? city : null,
      state: state != null && state.isNotEmpty ? state : null,
      districtSlug: district != null && district.isNotEmpty ? district : null,
    );
  }
}

/// Summary row for district (customer) browse.
class MealviewerDistrictSummary {
  const MealviewerDistrictSummary({
    required this.districtSlug,
    required this.label,
    this.stateCode,
  });

  final String districtSlug;
  final String label;
  final String? stateCode;

  static MealviewerDistrictSummary? fromCustomerJson(Map<String, dynamic> raw) {
    final slug = (raw['districtLookup'] as String?)?.trim();
    if (slug == null || slug.isEmpty || slug == '-') {
      final username = (raw['username'] as String?)?.trim();
      if (username == null || username.isEmpty) {
        return null;
      }
      final email = (raw['email'] as String?)?.trim();
      final label = email != null && email.isNotEmpty ? email : username;
      return MealviewerDistrictSummary(
        districtSlug: username,
        label: label,
        stateCode: (raw['stateCode'] as String?)?.trim(),
      );
    }
    final email = (raw['email'] as String?)?.trim();
    final username = (raw['username'] as String?)?.trim();
    final label = email != null && email.isNotEmpty
        ? email
        : (username != null && username.isNotEmpty ? username : slug);
    return MealviewerDistrictSummary(
      districtSlug: slug,
      label: label,
      stateCode: (raw['stateCode'] as String?)?.trim(),
    );
  }
}

/// HTTP client for MealViewer public v4 API.
class MealviewerApiClient {
  MealviewerApiClient({
    http.Client? httpClient,
    String baseUrl = kMealviewerApiDefaultBaseUrl,
  })  : _http = httpClient ?? http.Client(),
        _baseUrl = _stripTrailingSlash(baseUrl);

  final http.Client _http;
  final String _baseUrl;

  static List<MealviewerDistrictSummary>? _districtCache;
  static DateTime? _districtCacheAt;
  static const Duration _districtCacheTtl = Duration(hours: 6);

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// `MM-DD-YYYY` range segment for menu URLs.
  static String formatMealviewerApiDate(DateTime utcDay) {
    final m = utcDay.month.toString().padLeft(2, '0');
    final d = utcDay.day.toString().padLeft(2, '0');
    final y = utcDay.year.toString();
    return '$m-$d-$y';
  }

  Future<Map<String, dynamic>?> fetchSchoolMenu({
    required String schoolSlug,
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
  }) async {
    final slug = normalizeMealviewerSchoolSlug(schoolSlug);
    if (slug == null) {
      return null;
    }
    final start = formatMealviewerApiDate(rangeStartUtc);
    final end = formatMealviewerApiDate(rangeEndUtc);
    final uri = _uri('/api/v4/school/$slug/$start/$end/');
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(decodeRssHttpResponseBody(res));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<MealviewerSchoolSummary?> fetchPhysicalLocation(String schoolSlug) async {
    final slug = normalizeMealviewerSchoolSlug(schoolSlug);
    if (slug == null) {
      return null;
    }
    final uri = _uri('/api/v4/physicalLocation/$slug');
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(decodeRssHttpResponseBody(res));
    if (decoded is Map<String, dynamic>) {
      return MealviewerSchoolSummary.fromPhysicalLocationJson(decoded);
    }
    return null;
  }

  Future<List<MealviewerSchoolSummary>> searchSchools(
    String query, {
    int limit = 25,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const [];
    }
    final encoded = Uri.encodeComponent(q);
    final uri = _uri('/api/v4/physicalLocation/search/$encoded');
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      return const [];
    }
    final decoded = jsonDecode(decodeRssHttpResponseBody(res));
    return _schoolsFromListResponse(decoded, limit: limit);
  }

  Future<List<MealviewerSchoolSummary>> listDistrictSchools(
    String districtSlug, {
    int limit = 200,
  }) async {
    final slug = districtSlug.trim();
    if (slug.isEmpty) {
      return const [];
    }
    final encoded = Uri.encodeComponent(slug);
    final uri = _uri('/api/v4/physicalLocation/district/$encoded');
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      return const [];
    }
    final decoded = jsonDecode(decodeRssHttpResponseBody(res));
    return _schoolsFromListResponse(decoded, limit: limit);
  }

  Future<List<MealviewerDistrictSummary>> listDistricts({
    String? query,
    int limit = 50,
  }) async {
    final all = await _loadDistricts();
    final q = query?.trim().toLowerCase() ?? '';
    final filtered = q.isEmpty
        ? all
        : all.where((d) {
            return d.districtSlug.toLowerCase().contains(q) ||
                d.label.toLowerCase().contains(q) ||
                (d.stateCode?.toLowerCase().contains(q) ?? false);
          }).toList();
    if (filtered.length <= limit) {
      return filtered;
    }
    return filtered.sublist(0, limit);
  }

  Future<List<MealviewerDistrictSummary>> _loadDistricts() async {
    final now = DateTime.now().toUtc();
    if (_districtCache != null &&
        _districtCacheAt != null &&
        now.difference(_districtCacheAt!) < _districtCacheTtl) {
      return _districtCache!;
    }
    final uri = _uri('/api/v4/customer');
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      return const [];
    }
    final decoded = jsonDecode(decodeRssHttpResponseBody(res));
    final out = <MealviewerDistrictSummary>[];
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List<dynamic>) {
        for (final row in data) {
          if (row is Map<String, dynamic>) {
            final parsed = MealviewerDistrictSummary.fromCustomerJson(row);
            if (parsed != null) {
              out.add(parsed);
            }
          }
        }
      }
    }
    out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    _districtCache = out;
    _districtCacheAt = now;
    return out;
  }

  List<MealviewerSchoolSummary> _schoolsFromListResponse(
    Object? decoded, {
    required int limit,
  }) {
    final out = <MealviewerSchoolSummary>[];
    if (decoded is! Map<String, dynamic>) {
      return out;
    }
    final data = decoded['data'];
    if (data is! List<dynamic>) {
      return out;
    }
    for (final row in data) {
      if (row is Map<String, dynamic>) {
        final parsed = MealviewerSchoolSummary.fromPhysicalLocationJson(row);
        if (parsed != null) {
          out.add(parsed);
        }
      }
      if (out.length >= limit) {
        break;
      }
    }
    return out;
  }

  static String _stripTrailingSlash(String raw) {
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Safe URI for diagnostics (no secrets).
  String menuUriForLog(String schoolSlug, DateTime start, DateTime end) {
    final slug = normalizeMealviewerSchoolSlug(schoolSlug) ?? schoolSlug;
    final s = formatMealviewerApiDate(start);
    final e = formatMealviewerApiDate(end);
    return safeHttpUriForLog(_uri('/api/v4/school/$slug/$s/$e/'));
  }
}
