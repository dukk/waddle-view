import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/config/provider_config_resolver.dart';
import 'package:waddle_display/config/provider_runtime_config.dart';
import 'package:waddle_display/data/data_write_context.dart';
import 'package:waddle_display/data/providers/pexels/pexels_data_provider.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/secrets/in_memory_secret_store.dart';
import 'package:waddle_display/secrets/secret_store.dart';
import 'package:waddle_display/blob/blob_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

const _jpegBytes = <int>[0xFF, 0xD8, 0xFF, 0xD9];
const _mp4Bytes = <int>[0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70];

http.StreamedResponse _jsonResponse(Object body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
    headers: {'content-type': 'application/json'},
  );
}

http.StreamedResponse _bytesResponse(List<int> bytes) {
  return http.StreamedResponse(Stream.value(bytes), 200);
}

Map<String, dynamic> _photoJson(int id) => {
  'id': id,
  'url': 'https://www.pexels.com/photo/$id/',
  'photographer': 'Pat Example',
  'photographer_url': 'https://www.pexels.com/@pat',
  'alt': 'Sample',
  'src': {'large': 'http://images.test/p$id.jpg'},
};

Map<String, dynamic> _videoJson(int id, int duration) => {
  'id': id,
  'duration': duration,
  'url': 'https://www.pexels.com/video/$id/',
  'user': {
    'name': 'Sam Example',
    'url': 'https://www.pexels.com/@sam',
  },
  'video_files': [
    {
      'link': 'http://video.test/v$id.mp4',
      'file_type': 'video/mp4',
      'width': 1280,
    },
  ],
};

class _StatusClient extends http.BaseClient {
  _StatusClient(this.code);
  final int code;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(utf8.encode('')), code);
  }
}

class _BodyClient extends http.BaseClient {
  _BodyClient(this.body, this.code);
  final String body;
  final int code;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(utf8.encode(body)), code);
  }
}

class _FakePexelsHttp extends http.BaseClient {
  _FakePexelsHttp({
    this.curatedPhotos = const [],
    this.popularVideos = const [],
    Map<String, List<Map<String, dynamic>>>? searchPhotosByQuery,
    Map<String, List<Map<String, dynamic>>>? searchVideosByQuery,
    this.emptyImage = false,
    this.throwOnImage = false,
  })  : searchPhotosByQuery = searchPhotosByQuery ?? {},
        searchVideosByQuery = searchVideosByQuery ?? {};

  final List<Map<String, dynamic>> curatedPhotos;
  final List<Map<String, dynamic>> popularVideos;
  final Map<String, List<Map<String, dynamic>>> searchPhotosByQuery;
  final Map<String, List<Map<String, dynamic>>> searchVideosByQuery;
  final bool emptyImage;
  final bool throwOnImage;

  final List<String> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    requests.add(u.toString());
    if (u.host == 'images.test') {
      if (throwOnImage) {
        throw StateError('image download failed');
      }
      if (emptyImage) {
        return http.StreamedResponse(Stream.value(utf8.encode('')), 200);
      }
      return _bytesResponse(_jpegBytes);
    }
    if (u.host == 'video.test') {
      return _bytesResponse(_mp4Bytes);
    }
    if (u.path == '/v1/curated') {
      return _jsonResponse({
        'photos': curatedPhotos,
        'next_page': null,
      });
    }
    if (u.path == '/v1/videos/popular') {
      return _jsonResponse({
        'videos': popularVideos,
        'next_page': null,
      });
    }
    if (u.path == '/v1/search') {
      final q = u.queryParameters['query'] ?? '';
      final photos = searchPhotosByQuery[q] ?? const [];
      return _jsonResponse({'photos': photos, 'next_page': null});
    }
    if (u.path == '/v1/videos/search') {
      final q = u.queryParameters['query'] ?? '';
      final videos = searchVideosByQuery[q] ?? const [];
      return _jsonResponse({'videos': videos, 'next_page': null});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
  }
}

Future<void> _ensurePexelsProvider(
  AppDatabase db, {
  String extra = '{"maxPhotos":100,"maxVideos":100,"photosPerHour":2,"videosPerHour":2,'
      '"minVideoSeconds":11,"maxVideoSeconds":29,"sources":[]}',
  int pollSeconds = 0,
}) async {
  await db.into(db.providerSettings).insertOnConflictUpdate(
        ProviderSettingsCompanion.insert(
          id: 'pexels',
          providerType: 'pexels',
          pollSeconds: Value(pollSeconds),
          baseUrl: const Value('http://api.pexels.test'),
          configJson: Value(extra),
        ),
      );
}

void main() {
  test('collect is a no-op when provider disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insertOnConflictUpdate(
          ProviderSettingsCompanion.insert(
            id: 'pexels',
            providerType: 'pexels',
            enabled: const Value(false),
            pollSeconds: const Value(0),
            baseUrl: const Value('http://api.pexels.test'),
          ),
        );
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [_photoJson(1)],
      popularVideos: [_videoJson(2, 20)],
    );
    await PexelsDataProvider(
      httpClient: httpClient,
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect(httpClient.requests, isEmpty);
    await db.close();
  });

  test('collect skips when API key missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    final secrets = InMemorySecretStore();
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [_photoJson(1)],
      popularVideos: [],
    );
    await PexelsDataProvider(httpClient: httpClient, nowMs: () => 1).collect(
      _ctx(db, secrets),
    );
    expect(httpClient.requests, isEmpty);
    await db.close();
  });

  test('collect respects poll interval via config kv', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db, pollSeconds: 60);
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kPexelsLastCollectKvKey,
            value: '100000',
          ),
        );
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [_photoJson(1)],
      popularVideos: [],
    );
    await PexelsDataProvider(httpClient: httpClient, nowMs: () => 100001).collect(
      _ctx(db, await _secretsWithKey()),
    );
    expect(httpClient.requests, isEmpty);
    await db.close();
  });

  test('collect downloads photo and video when quota allows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);

    final secrets = await _secretsWithKey();
    final ctx = _ctx(db, secrets);
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [_photoJson(101)],
      popularVideos: [_videoJson(201, 22)],
    );

    final provider = PexelsDataProvider(
      httpClient: httpClient,
      nowMs: () => 1_000_000,
    );
    await provider.collect(ctx);

    final photos = await db.select(db.photos).get();
    final videos = await db.select(db.videos).get();
    expect(photos.length, 1);
    expect(photos.single.id, '101');
    expect(videos.length, 1);
    expect(videos.single.id, '201');

    final batches = await db.select(db.pexelsFetchBatches).get();
    expect(batches.length, 2);
    expect(batches.where((b) => b.kind == 'photo').length, 1);
    expect(batches.where((b) => b.kind == 'video').length, 1);

    expect(httpClient.requests.any((r) => r.contains('/v1/curated')), isTrue);
    expect(httpClient.requests.any((r) => r.contains('/v1/videos/popular')), isTrue);
    await db.close();
  });

  test('collect skips new photos when hourly photo cap is reached', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);

    await db.into(db.pexelsFetchBatches).insert(
          PexelsFetchBatchesCompanion.insert(
            requestedAtMs: DateTime.fromMillisecondsSinceEpoch(999_500),
            kind: 'photo',
            count: const Value(2),
          ),
        );

    final secrets = await _secretsWithKey();
    final ctx = _ctx(db, secrets);
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [_photoJson(303)],
      popularVideos: [],
    );

    await PexelsDataProvider(
      httpClient: httpClient,
      nowMs: () => 1_000_000,
    ).collect(ctx);

    final photos = await db.select(db.photos).get();
    expect(photos, isEmpty);
    expect(
      httpClient.requests.where((r) => r.contains('/v1/curated')).length,
      0,
    );
    await db.close();
  });

  test('collect skips duplicate Pexels photo ids', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);

    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: '404',
            category: const Value('pexels'),
            mediaBlobKey: 'pexels/photo/404/image',
            photographerName: 'x',
            photographerUrl: 'http://x',
            pexelsPageUrl: 'http://p',
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(100),
          ),
        );

    final secrets = await _secretsWithKey();
    final ctx = _ctx(db, secrets);
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [_photoJson(404)],
      popularVideos: [],
    );

    await PexelsDataProvider(
      httpClient: httpClient,
      nowMs: () => 2_000_000,
    ).collect(ctx);

    expect((await db.select(db.photos).get()).length, 1);
    await db.close();
  });

  test('prune removes oldest photos above maxPhotos', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(
      db,
      extra: '{"maxPhotos":2,"maxVideos":100,"photosPerHour":2,"videosPerHour":2,'
          '"minVideoSeconds":11,"maxVideoSeconds":29,"sources":[]}',
    );

    for (final e in <(String, int)>[
      ('1', 10),
      ('2', 20),
      ('3', 30),
    ]) {
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: e.$1,
              category: const Value('pexels'),
              mediaBlobKey: 'k/${e.$1}',
              photographerName: 'a',
              photographerUrl: 'b',
              pexelsPageUrl: 'c',
              fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(e.$2),
            ),
          );
    }

    final secrets = await _secretsWithKey();
    final ctx = _ctx(db, secrets);
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(curatedPhotos: [], popularVideos: []),
      nowMs: () => 100_000,
    ).collect(ctx);

    final ids =
        (await db.select(db.photos).get()).map((p) => p.id).toList()..sort();
    expect(ids, ['2', '3']);
    await db.close();
  });

  test('extra sources hit search endpoints', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(
      db,
      extra: '{"sources":[{"query":"trees","category":"nature"}]}',
    );

    final secrets = await _secretsWithKey();
    final ctx = _ctx(db, secrets);
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [],
      popularVideos: [],
      searchPhotosByQuery: {
        'trees': [_photoJson(501)],
      },
      searchVideosByQuery: {
        'trees': [_videoJson(502, 15)],
      },
    );

    await PexelsDataProvider(
      httpClient: httpClient,
      nowMs: () => 5_000_000,
    ).collect(ctx);

    expect(
      httpClient.requests.any(
        (r) => r.contains('/v1/search') && r.contains('trees'),
      ),
      isTrue,
    );
    expect(
      httpClient.requests.any(
        (r) => r.contains('/v1/videos/search') && r.contains('trees'),
      ),
      isTrue,
    );
    expect(httpClient.requests.any((r) => r.contains('/v1/curated')), isFalse);
    expect(
      httpClient.requests.any((r) => r.contains('/v1/videos/popular')),
      isFalse,
    );

    final photo = await (db.select(db.photos)
          ..where((t) => t.id.equals('501')))
        .getSingleOrNull();
    expect(photo?.category, 'nature');
    await db.close();
  });

  test('search sources are fetched in round-robin under shared budgets', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(
      db,
      extra: '{"photosPerHour":2,"videosPerHour":2,'
          '"sources":['
          '{"query":"q1","category":"cat1"},'
          '{"query":"q2","category":"cat2"}'
          ']}',
    );

    final secrets = await _secretsWithKey();
    final ctx = _ctx(db, secrets);
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [],
      popularVideos: [],
      searchPhotosByQuery: {
        'q1': [_photoJson(9001)],
        'q2': [_photoJson(9002)],
      },
      searchVideosByQuery: {
        'q1': [_videoJson(9101, 15)],
        'q2': [_videoJson(9102, 16)],
      },
    );

    await PexelsDataProvider(
      httpClient: httpClient,
      nowMs: () => 9_000_000,
    ).collect(ctx);

    final photos = await db.select(db.photos).get();
    final videos = await db.select(db.videos).get();
    expect(photos.map((p) => p.category).toSet(), {'cat1', 'cat2'});
    expect(videos.map((v) => v.category).toSet(), {'cat1', 'cat2'});

    expect(
      httpClient.requests.any((r) => r.contains('/v1/search') && r.contains('q1')),
      isTrue,
    );
    expect(
      httpClient.requests.any((r) => r.contains('/v1/search') && r.contains('q2')),
      isTrue,
    );
    expect(
      httpClient.requests.any(
        (r) => r.contains('/v1/videos/search') && r.contains('q1'),
      ),
      isTrue,
    );
    expect(
      httpClient.requests.any(
        (r) => r.contains('/v1/videos/search') && r.contains('q2'),
      ),
      isTrue,
    );
    await db.close();
  });

  test('prune removes oldest videos above maxVideos', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(
      db,
      extra: '{"maxPhotos":100,"maxVideos":2,"photosPerHour":2,"videosPerHour":2,'
          '"minVideoSeconds":11,"maxVideoSeconds":29,"sources":[]}',
    );

    for (final e in <(String, int)>[
      ('va', 10),
      ('vb', 20),
      ('vc', 30),
    ]) {
      await db.into(db.videos).insert(
            VideosCompanion.insert(
              id: e.$1,
              category: const Value('pexels'),
              mediaBlobKey: 'k/${e.$1}',
              photographerName: 'a',
              photographerUrl: 'b',
              pexelsPageUrl: 'c',
              durationSeconds: 20,
              fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(e.$2),
            ),
          );
    }

    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(curatedPhotos: [], popularVideos: []),
      nowMs: () => 200_000,
    ).collect(_ctx(db, await _secretsWithKey()));

    final ids =
        (await db.select(db.videos).get()).map((v) => v.id).toList()..sort();
    expect(ids, ['vb', 'vc']);
    await db.close();
  });

  test('strips trailing slash from configured baseUrl', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insertOnConflictUpdate(
          ProviderSettingsCompanion.insert(
            id: 'pexels',
            providerType: 'pexels',
            pollSeconds: const Value(0),
            baseUrl: const Value('http://api.pexels.test/'),
            configJson: const Value('{}'),
          ),
        );
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [_photoJson(801)],
      popularVideos: [],
    );
    await PexelsDataProvider(httpClient: httpClient, nowMs: () => 1).collect(
      _ctx(db, await _secretsWithKey()),
    );
    expect(
      httpClient.requests.any((r) => r.startsWith('http://api.pexels.test/v1/')),
      isTrue,
    );
    await db.close();
  });

  test('API non-200 skips insert', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    await PexelsDataProvider(
      httpClient: _StatusClient(500),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('invalid JSON from API is ignored', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    await PexelsDataProvider(
      httpClient: _BodyClient('oops not json', 200),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('non-object JSON body returns null from API helper path', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    await PexelsDataProvider(
      httpClient: _BodyClient('[]', 200),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('empty image download skips insert', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    final photo = Map<String, dynamic>.from(_photoJson(903))
      ..['src'] = {'large': 'http://images.test/empty.jpg'};
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(
        curatedPhotos: [photo],
        popularVideos: [],
        emptyImage: true,
      ),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('photo uses original when large missing', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    final photo = Map<String, dynamic>.from(_photoJson(902))
      ..['src'] = {'original': 'http://images.test/o.jpg'};
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(curatedPhotos: [photo], popularVideos: []),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect((await db.select(db.photos).get()).single.id, '902');
    await db.close();
  });

  test('collect skips new videos when hourly video cap is reached', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    await db.into(db.pexelsFetchBatches).insert(
          PexelsFetchBatchesCompanion.insert(
            requestedAtMs: DateTime.fromMillisecondsSinceEpoch(99_500),
            kind: 'video',
            count: const Value(2),
          ),
        );
    final httpClient = _FakePexelsHttp(
      curatedPhotos: [],
      popularVideos: [_videoJson(777, 20)],
    );
    await PexelsDataProvider(
      httpClient: httpClient,
      nowMs: () => 100_000,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect(await db.select(db.videos).get(), isEmpty);
    expect(
      httpClient.requests.where((r) => r.contains('/videos/popular')).length,
      0,
    );
    await db.close();
  });

  test('video search skips duration outside configured window', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(
      db,
      extra: '{"sources":[{"query":"x","category":"misc"}]}',
    );

    final secrets = await _secretsWithKey();
    final ctx = _ctx(db, secrets);
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(
        curatedPhotos: [],
        popularVideos: [],
        searchVideosByQuery: {
          'x': [_videoJson(601, 5), _videoJson(602, 35), _videoJson(603, 18)],
        },
      ),
      nowMs: () => 8_000_000,
    ).collect(ctx);

    final rows = await db.select(db.videos).get();
    expect(rows.map((e) => e.id).toList(), ['603']);
    await db.close();
  });

  test('provider id and default http client construction', () {
    final p = PexelsDataProvider(nowMs: () => 0);
    expect(p.id, kPexelsProviderId);
  });

  test('collect returns when resolveConfig throws', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    final secrets = await _secretsWithKey();
    final ctx = _ThrowingResolveContext(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
    );
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(curatedPhotos: [_photoJson(1)]),
      nowMs: () => 1,
    ).collect(ctx);
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('second curated page is requested when next_page is set', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    final client = _TwoPageCuratedClient();
    await PexelsDataProvider(httpClient: client, nowMs: () => 1).collect(
      _ctx(db, await _secretsWithKey()),
    );
    expect(client.curatedPageRequests, 2);
    await db.close();
  });

  test('prune removes oldest row and deletes blob metadata for it', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(
      db,
      extra: '{"maxPhotos":1,"maxVideos":100,"photosPerHour":2,"videosPerHour":2,'
          '"minVideoSeconds":11,"maxVideoSeconds":29,"sources":[]}',
    );
    final blobs = FakeBlobStore();
    final secrets = await _secretsWithKey();
    for (final e in <(String, int)>[('o1', 10), ('o2', 20)]) {
      final ref = await blobs.putBytes(_jpegBytes, logicalKey: 'k/${e.$1}');
      await db.into(db.blobMetadata).insert(
            BlobMetadataCompanion.insert(
              blobKey: 'k/${e.$1}',
              sha256: ref.storageKey.split('/').last,
              relativePath: ref.storageKey,
              bytes: _jpegBytes.length,
              capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          );
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: e.$1,
              category: const Value('pexels'),
              mediaBlobKey: 'k/${e.$1}',
              photographerName: 'a',
              photographerUrl: 'b',
              pexelsPageUrl: 'c',
              fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(e.$2),
            ),
          );
    }
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(curatedPhotos: [], popularVideos: []),
      nowMs: () => 300,
    ).collect(
      DataWriteContextImpl(
        db: db,
        blobs: blobs,
        secrets: secrets,
        resolve: ProviderConfigResolver(db, secrets).resolve,
      ),
    );
    expect((await db.select(db.photos).get()).single.id, 'o2');
    final meta = await db.select(db.blobMetadata).get();
    expect(meta.length, 1);
    expect(meta.single.blobKey, 'k/o2');
    await db.close();
  });

  test('skips non-map photo entries and accepts string ids', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    final photo = Map<String, dynamic>.from(_photoJson(1))..['id'] = 'sid';
    await PexelsDataProvider(
      httpClient: _MixedPhotosCuratedClient(photo),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect((await db.select(db.photos).get()).single.id, 'sid');
    await db.close();
  });

  test('download exception skips photo insert', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(
        curatedPhotos: [_photoJson(606)],
        popularVideos: [],
        throwOnImage: true,
      ),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('video duration as double is accepted', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _ensurePexelsProvider(db);
    final v = Map<String, dynamic>.from(_videoJson(707, 20));
    v['duration'] = 20.0;
    await PexelsDataProvider(
      httpClient: _FakePexelsHttp(curatedPhotos: [], popularVideos: [v]),
      nowMs: () => 1,
    ).collect(_ctx(db, await _secretsWithKey()));
    expect((await db.select(db.videos).get()).single.id, '707');
    await db.close();
  });
}

class _ThrowingResolveContext implements DataWriteContext {
  _ThrowingResolveContext({
    required this.db,
    required this.blobs,
    required this.secrets,
  });

  @override
  final AppDatabase db;

  @override
  final BlobStore blobs;

  @override
  final SecretStore secrets;

  @override
  Future<ProviderRuntimeConfig> resolveConfig(String providerId) async {
    throw StateError('unavailable');
  }
}

class _MixedPhotosCuratedClient extends http.BaseClient {
  _MixedPhotosCuratedClient(this._validPhoto);
  final Map<String, dynamic> _validPhoto;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.path == '/v1/curated') {
      return _jsonResponse({
        'photos': [42, _validPhoto],
        'next_page': null,
      });
    }
    if (u.host == 'images.test') {
      return _bytesResponse(_jpegBytes);
    }
    if (u.path == '/v1/videos/popular') {
      return _jsonResponse({'videos': [], 'next_page': null});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
  }
}

class _TwoPageCuratedClient extends http.BaseClient {
  int curatedPageRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.path == '/v1/curated') {
      curatedPageRequests++;
      if (curatedPageRequests == 1) {
        return _jsonResponse({
          'photos': [_photoJson(301)],
          'next_page': 'x',
        });
      }
      return _jsonResponse({'photos': [], 'next_page': null});
    }
    if (u.host == 'images.test') {
      return _bytesResponse(_jpegBytes);
    }
    if (u.path == '/v1/videos/popular') {
      return _jsonResponse({'videos': [], 'next_page': null});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('')), 404);
  }
}

Future<InMemorySecretStore> _secretsWithKey() async {
  final secrets = InMemorySecretStore();
  await secrets.write('${ProviderConfigResolver.accessTokenKey}:pexels', 'k');
  return secrets;
}

DataWriteContext _ctx(AppDatabase db, InMemorySecretStore secrets) {
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}
