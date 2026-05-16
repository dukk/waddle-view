import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/provider_access_token_env.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/media_flickr/flickr_media_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('skip when disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(db, enabled: false);
    final client = _FlickrClient();
    await FlickrMediaDataProvider(httpClient: client).collect(
      _ctx(db, InMemorySecretStore()),
    );
    expect(client.listCalls, 0);
    await db.close();
  });

  test('skip when api key missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(db);
    final client = _FlickrClient();
    await FlickrMediaDataProvider(httpClient: client).collect(
      _ctx(db, InMemorySecretStore(), env: const {}),
    );
    expect(client.listCalls, 0);
    await db.close();
  });

  test('ingests one group photo into photos and blob metadata', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(db);
    final secrets = InMemorySecretStore();
    final client = _FlickrClient(
      photosByGroup: {
        'g1': [
          {
            'id': '123',
            'owner': 'ownerA',
            'ownername': 'Pat',
            'title': 'Sunset',
            'url_l': 'https://live.staticflickr.com/1/123_s.jpg',
            'width_l': '640',
            'height_l': '480',
          },
        ],
      },
    );
    await FlickrMediaDataProvider(httpClient: client, nowMs: () => 1000).collect(
      _ctx(db, secrets),
    );
    final photos = await db.select(db.photos).get();
    expect(photos.length, 1);
    expect(photos.single.id, 'flickr:123');
    expect(photos.single.dataProvider, kMediaDataProviderFlickr);
    expect(photos.single.category, 'flickr');
    expect(photos.single.photographerName, 'Pat');
    final blobs = await db.select(db.blobMetadata).get();
    expect(blobs.length, 1);
    expect(blobs.single.pixelWidth, 640);
    expect(blobs.single.pixelHeight, 480);
    await db.close();
  });

  test('perPollLimit caps inserts across groups', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      configJson:
          '{"groupIds":["g1","g2"],"category":"flickr","perPollLimit":1,"sort":"date-posted-desc"}',
    );
    final secrets = InMemorySecretStore();
    final client = _FlickrClient(
      photosByGroup: {
        'g1': [
          {
            'id': '1',
            'owner': 'a',
            'ownername': 'A',
            'title': 'a',
            'url_l': 'https://live.staticflickr.com/1/1_a.jpg',
          },
        ],
        'g2': [
          {
            'id': '2',
            'owner': 'b',
            'ownername': 'B',
            'title': 'b',
            'url_l': 'https://live.staticflickr.com/1/2_b.jpg',
          },
        ],
      },
    );
    await FlickrMediaDataProvider(httpClient: client).collect(_ctx(db, secrets));
    expect((await db.select(db.photos).get()).length, 1);
    await db.close();
  });

  test('second collect keeps idempotent rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      pollSeconds: 0,
      configJson:
          '{"groupIds":["g1"],"category":"flickr","perPollLimit":10,"sort":"date-posted-desc"}',
    );
    final secrets = InMemorySecretStore();
    final client = _FlickrClient(
      photosByGroup: {
        'g1': [
          {
            'id': 'same',
            'owner': 'a',
            'ownername': 'A',
            'title': 'same',
            'url_l': 'https://live.staticflickr.com/1/same_a.jpg',
          },
        ],
      },
    );
    final provider = FlickrMediaDataProvider(httpClient: client, nowMs: () => 2000);
    await provider.collect(_ctx(db, secrets));
    await provider.collect(_ctx(db, secrets));
    expect((await db.select(db.photos).get()).length, 1);
    await db.close();
  });
}

DataWriteContext _ctx(
  AppDatabase db,
  InMemorySecretStore secrets, {
  Map<String, String> env = const {waddleFlickrApiKeyEnv: 'k'},
}) {
  final resolver = ProviderConfigResolver(db, env);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

Future<void> _seedProvider(
  AppDatabase db, {
  bool enabled = true,
  int pollSeconds = 0,
  String configJson =
      '{"groupIds":["g1"],"category":"flickr","perPollLimit":20,"sort":"date-posted-desc"}',
}) async {
  await db.into(db.integrations).insertOnConflictUpdate(
        IntegrationsCompanion.insert(
          id: kFlickrMediaProviderId,
          providerType: 'media_flickr',
          enabled: Value(enabled),
          pollSeconds: Value(pollSeconds),
          baseUrl: const Value('https://api.flickr.com/services/rest'),
          configJson: Value(configJson),
        ),
      );
}

class _FlickrClient extends http.BaseClient {
  _FlickrClient({Map<String, List<Map<String, dynamic>>>? photosByGroup})
      : _photosByGroup = photosByGroup ?? const {};

  final Map<String, List<Map<String, dynamic>>> _photosByGroup;
  int listCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'api.flickr.com' &&
        u.queryParameters['method'] == 'flickr.groups.pools.getPhotos') {
      listCalls++;
      final gid = u.queryParameters['group_id'] ?? '';
      final photos = _photosByGroup[gid] ?? const <Map<String, dynamic>>[];
      return _json({
        'stat': 'ok',
        'photos': {'photo': photos},
      });
    }
    if (u.host == 'live.staticflickr.com') {
      return http.StreamedResponse(Stream.value([1, 2, 3]), 200);
    }
    return http.StreamedResponse(Stream.value([]), 404);
  }

  http.StreamedResponse _json(Object obj) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(obj))),
        200,
        headers: {'Content-Type': 'application/json'},
      );
}
