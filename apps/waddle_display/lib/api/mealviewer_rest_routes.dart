import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_integrations/calendar_mealviewer/mealviewer_api_client.dart';
const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

void registerMealviewerRestRoutes(
  Router r, {
  http.Client? httpClient,
}) {
  final client = httpClient ?? http.Client();

  r.get('/v1/mealviewer/schools/search', (Request req) async {
    final q = req.url.queryParameters['q']?.trim() ?? '';
    final limit = _parseLimit(req.url.queryParameters['limit'], defaultValue: 25);
    final api = MealviewerApiClient(httpClient: client);
    final items = await api.searchSchools(q, limit: limit);
    return Response.ok(
      jsonEncode({'items': items.map(_schoolToJson).toList()}),
      headers: _jsonHeaders,
    );
  });

  r.get('/v1/mealviewer/districts', (Request req) async {
    final q = req.url.queryParameters['q']?.trim();
    final limit = _parseLimit(req.url.queryParameters['limit'], defaultValue: 50);
    final api = MealviewerApiClient(httpClient: client);
    final items = await api.listDistricts(query: q, limit: limit);
    return Response.ok(
      jsonEncode({'items': items.map(_districtToJson).toList()}),
      headers: _jsonHeaders,
    );
  });

  r.get(
    '/v1/mealviewer/districts/<districtSlug>/schools',
    (Request req, String districtSlug) async {
      final limit =
          _parseLimit(req.url.queryParameters['limit'], defaultValue: 200);
      final api = MealviewerApiClient(httpClient: client);
      final items = await api.listDistrictSchools(districtSlug, limit: limit);
      return Response.ok(
        jsonEncode({'items': items.map(_schoolToJson).toList()}),
        headers: _jsonHeaders,
      );
    },
  );

  r.get(
    '/v1/mealviewer/schools/<schoolSlug>/probe',
    (Request req, String schoolSlug) async {
      final api = MealviewerApiClient(httpClient: client);
      final school = await api.fetchPhysicalLocation(schoolSlug);
      if (school == null) {
        return Response(
          404,
          body: '{"error":"school_not_found"}',
          headers: _jsonHeaders,
        );
      }
      final now = DateTime.now().toUtc();
      final menu = await api.fetchSchoolMenu(
        schoolSlug: school.schoolSlug,
        rangeStartUtc: now,
        rangeEndUtc: now,
      );
      return Response.ok(
        jsonEncode({
          'school': _schoolToJson(school),
          'menu_available': menu != null,
        }),
        headers: _jsonHeaders,
      );
    },
  );
}

int _parseLimit(String? raw, {required int defaultValue}) {
  final parsed = int.tryParse(raw ?? '');
  if (parsed == null || parsed <= 0) {
    return defaultValue;
  }
  return parsed > 200 ? 200 : parsed;
}

Map<String, Object?> _schoolToJson(MealviewerSchoolSummary s) => {
      'school_slug': s.schoolSlug,
      'label': s.label,
      if (s.city != null) 'city': s.city,
      if (s.state != null) 'state': s.state,
      if (s.districtSlug != null) 'district_slug': s.districtSlug,
    };

Map<String, Object?> _districtToJson(MealviewerDistrictSummary d) => {
      'district_slug': d.districtSlug,
      'label': d.label,
      if (d.stateCode != null) 'state_code': d.stateCode,
    };
