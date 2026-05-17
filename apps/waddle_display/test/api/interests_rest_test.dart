import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';
import '../helpers/rest_auth_helper.dart';

void main() {
  test('GET/POST/PATCH/DELETE weather location', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
      body: jsonEncode({
        'id': 'sea',
        'name': 'Seattle',
        'latitude': 47.6,
        'longitude': -122.3,
        'enabled': true,
        'include_active_weather_alerts': false,
      }),
    );
    expect(create.statusCode, 200);

    final list = await http.get(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
    );
    expect(list.statusCode, 200);
    final items = (jsonDecode(list.body) as Map)['items'] as List;
    expect(items.length, 1);
    expect(items.first['id'], 'sea');

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/weather-locations/sea'),
      headers: auth,
      body: jsonEncode({'name': 'Seattle, WA'}),
    );
    expect(patch.statusCode, 200);

    final del = await http.delete(
      Uri.parse('$base/v1/interests/weather-locations/sea'),
      headers: auth,
    );
    expect(del.statusCode, 200);

    final listAfter = await http.get(
      Uri.parse('$base/v1/interests/weather-locations'),
      headers: auth,
    );
    expect(
      ((jsonDecode(listAfter.body) as Map)['items'] as List).length,
      0,
    );
  });

  test('DELETE weather location blocked when weather_current exists', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'loc',
            name: 'X',
            latitude: 1,
            longitude: 2,
          ),
        );
    await db.into(db.weatherCurrent).insert(
          WeatherCurrentCompanion.insert(
            locationId: 'loc',
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/interests/weather-locations/loc'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 409);
  });

  test('RSS feed CRUD and delete blocked when articles exist', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await seedContentCategoriesForTest(db, ['general']);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/rss-feeds'),
      headers: auth,
      body: jsonEncode({
        'id': 'f1',
        'url': 'https://example.com/rss.xml',
        'category': 'general',
      }),
    );
    expect(create.statusCode, 200);

    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 'T',
            link: 'https://example.com/a',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );

    final delBlocked = await http.delete(
      Uri.parse('$base/v1/interests/rss-feeds/f1'),
      headers: auth,
    );
    expect(delBlocked.statusCode, 409);
  });

  test('joke category requires curator category id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);

    final missing = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/joke-categories'),
      headers: h.authHeaders,
      body: jsonEncode({'id': 'orphan', 'label': 'Orphan'}),
    );
    expect(missing.statusCode, 400);

    await seedContentCategoriesForTest(db, ['dad']);
    final ok = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/joke-categories'),
      headers: h.authHeaders,
      body: jsonEncode({'id': 'dad', 'label': 'Dad jokes'}),
    );
    expect(ok.statusCode, 200);
  });

  test('GET/POST/PATCH/DELETE home assistant entity', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db);
    addTearDown(h.dispose);
    final base = h.baseUrl;
    final auth = h.authHeaders;

    final create = await http.post(
      Uri.parse('$base/v1/interests/home-assistant-entities'),
      headers: auth,
      body: jsonEncode({
        'id': 'kitchen_temp',
        'entity_id': 'sensor.kitchen_temperature',
        'display_name': 'Kitchen',
        'enabled': true,
      }),
    );
    expect(create.statusCode, 200);

    final list = await http.get(
      Uri.parse('$base/v1/interests/home-assistant-entities'),
      headers: auth,
    );
    expect(list.statusCode, 200);
    final items = (jsonDecode(list.body) as Map)['items'] as List;
    expect(items.length, 1);
    expect(items.first['entity_id'], 'sensor.kitchen_temperature');

    final patch = await http.patch(
      Uri.parse('$base/v1/interests/home-assistant-entities/kitchen_temp'),
      headers: auth,
      body: jsonEncode({'display_name': 'Kitchen temp'}),
    );
    expect(patch.statusCode, 200);

    await db.into(db.homeAssistantEntityStates).insert(
          HomeAssistantEntityStatesCompanion.insert(
            entityId: 'sensor.kitchen_temperature',
            state: '21',
            attributesJson: '{}',
            observedAtMs: 1,
          ),
        );

    final del = await http.delete(
      Uri.parse('$base/v1/interests/home-assistant-entities/kitchen_temp'),
      headers: auth,
    );
    expect(del.statusCode, 200);

    expect(await db.select(db.homeAssistantEntityStates).get(), isEmpty);
  });

  test('power_viewer can read interests but not write', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db, role: kUserRolePowerViewer);
    addTearDown(h.dispose);

    final read = await http.get(
      Uri.parse('${h.baseUrl}/v1/interests/stock-symbols'),
      headers: h.authHeaders,
    );
    expect(read.statusCode, 200);

    final write = await http.post(
      Uri.parse('${h.baseUrl}/v1/interests/stock-symbols'),
      headers: h.authHeaders,
      body: jsonEncode({'id': 'x', 'symbol': 'X'}),
    );
    expect(write.statusCode, 403);
  });

  test('viewer cannot read interests', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final h = await RestTestHarness.start(database: db, role: kUserRoleViewer);
    addTearDown(h.dispose);

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/interests/rss-feeds'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });
}
