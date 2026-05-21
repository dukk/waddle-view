import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_display/api/mealviewer_rest_routes.dart';

class _MealviewerMockHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.contains('/physicalLocation/search/')) {
      final body = jsonEncode({
        'data': [
          {
            'physicalLocationLookup': 'ElmwoodElementary',
            'name': 'Elmwood Elementary',
            'city': 'Hopkinton',
            'state': 'Massachusetts',
          },
        ],
      });
      return _jsonResponse(body);
    }
    if (path.contains('/physicalLocation/district/')) {
      final body = jsonEncode({
        'data': [
          {
            'physicalLocationLookup': 'HopkintonHigh',
            'name': 'Hopkinton High',
          },
        ],
      });
      return _jsonResponse(body);
    }
    if (path.endsWith('/customer')) {
      final body = jsonEncode({
        'data': [
          {
            'districtLookup': 'Hopkinton',
            'username': 'HopkintonMA',
            'email': 'Hopkinton, MA',
            'stateCode': 'MA',
          },
        ],
      });
      return _jsonResponse(body);
    }
    if (path.contains('/physicalLocation/ElmwoodElementary')) {
      final body = jsonEncode({
        'physicalLocationLookup': 'ElmwoodElementary',
        'name': 'Elmwood Elementary',
      });
      return _jsonResponse(body);
    }
    if (path.contains('/school/ElmwoodElementary/')) {
      final body = jsonEncode({'menuSchedules': []});
      return _jsonResponse(body);
    }
    return _jsonResponse('{}', status: 404);
  }

  http.StreamedResponse _jsonResponse(String body, {int status = 200}) {
    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<Response> _get(Router r, String path) {
  return r.call(Request('GET', Uri.parse('http://test$path')));
}

void main() {
  test('GET mealviewer school search returns items', () async {
    final r = Router();
    registerMealviewerRestRoutes(r, httpClient: _MealviewerMockHttp());
    final res = await _get(r, '/v1/mealviewer/schools/search?q=elm');
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>;
    expect(items.length, 1);
    expect(items.single['school_slug'], 'ElmwoodElementary');
  });

  test('GET mealviewer districts returns items', () async {
    final r = Router();
    registerMealviewerRestRoutes(r, httpClient: _MealviewerMockHttp());
    final res = await _get(r, '/v1/mealviewer/districts?q=hop');
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>;
    expect(items, isNotEmpty);
  });

  test('GET mealviewer district schools returns items', () async {
    final r = Router();
    registerMealviewerRestRoutes(r, httpClient: _MealviewerMockHttp());
    final res = await _get(r, '/v1/mealviewer/districts/Hopkinton/schools');
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect((body['items'] as List).length, 1);
  });

  test('GET mealviewer school probe returns school', () async {
    final r = Router();
    registerMealviewerRestRoutes(r, httpClient: _MealviewerMockHttp());
    final res = await _get(r, '/v1/mealviewer/schools/ElmwoodElementary/probe');
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['menu_available'], isTrue);
    expect(body['school']['school_slug'], 'ElmwoodElementary');
  });
}
