import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/config/microsoft_graph_kv.dart'
    show
        kMicrosoftGraphAccessTokenExpiresAtKvKey,
        kOneDriveMediaDeltaLinkKvKey,
        kOneDriveMediaItemRowId,
        kOneDriveMediaLastCollectKvKey,
        microsoftGraphAccessTokenSecret;
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_data_providers/microsoft_graph/microsoft_graph_oauth.dart';
import 'package:waddle_data_providers/media_onedrive/onedrive_media_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

const String _testDeltaLink = 'https://graph.microsoft.com/v1.0/delta?token=test';

Map<String, Object?> _deltaPage(List<Object?> items) => {
      'value': items,
      '@odata.deltaLink': _testDeltaLink,
    };

void main() {
  test('skip when provider disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(db, accountsJson: '[]', enabled: false);
    final httpClient = _CountingClient();
    final ctx = await _ctx(db, InMemorySecretStore());
    await OneDriveMediaDataProvider(httpClient: httpClient).collect(ctx);
    expect(httpClient.requests, 0);
    await db.close();
  });

  test('skip when WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID unset', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insertOnConflictUpdate(
          IntegrationsCompanion.insert(
            id: kOneDriveMediaProviderId,
            integrationType: 'photo_onedrive',
            enabled: const Value(true),
            pollSeconds: const Value(0),
            baseUrl: const Value('https://graph.microsoft.com/v1.0'),
            configJson: const Value(
              '{"accounts":[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10}]}],"globalPerPollLimit":50}',
            ),
          ),
        );
    final httpClient = _CountingClient();
    final ctx = await _ctx(db, InMemorySecretStore(), clientId: null);
    await OneDriveMediaDataProvider(httpClient: httpClient).collect(ctx);
    expect(httpClient.requests, 0);
    await db.close();
  });

  test('no token skips sync without graph GET', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10}]}]',
    );
    final http = _CountingClient();
    final oauth = _NullGraphOAuth(httpClient: http, nowMs: () => 0);
    final ctx = await _ctx(db, InMemorySecretStore());
    await OneDriveMediaDataProvider(httpClient: http, oauth: oauth).collect(ctx);
    expect(http.requests, 0);
    await db.close();
  });

  test('account with empty sources does not request token', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson: '[{"graphAccountKey":"u","sources":[]}]',
    );
    final http = _CountingClient();
    final oauth = _ThrowingOAuth();
    final ctx = await _ctx(db, InMemorySecretStore());
    await OneDriveMediaDataProvider(httpClient: http, oauth: oauth).collect(ctx);
    expect(http.requests, 0);
    await db.close();
  });

  test('poll gate bypass when token expired inside window', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      pollSeconds: 3600,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '1',
          ),
        );
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kOneDriveMediaLastCollectKvKey,
            value: '${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
    final http = _GraphAndDownloadClient(
      deltaPages: [
        _deltaPage([_drivePhoto('x', 'https://dl.example.com/x')]),
      ],
    );
    final ctx = await _ctx(db, secrets);
    final oauth = _FixedTokenOAuth(httpClient: http, nowMs: () => 0);
    await OneDriveMediaDataProvider(httpClient: http, oauth: oauth).collect(ctx);
    expect(http.graphGets, greaterThan(0));
    await db.close();
  });

  test('graph folder resolve error JSON triggers error log path', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final http = _ErrorJsonGraphClient();
    final ctx = await _ctx(db, secrets);
    await OneDriveMediaDataProvider(httpClient: http).collect(ctx);
    expect(http.graphGets, 1);
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('follows @odata.nextLink for second page', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final http = _PagingGraphClient();
    final ctx = await _ctx(db, secrets);
    await OneDriveMediaDataProvider(httpClient: http).collect(ctx);
    expect(http.graphGets, 3);
    expect((await db.select(db.photos).get()).length, 2);
    await db.close();
  });

  test('downloads mp4 into videos', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/v","kind":"video","category":"vcat","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final http = _GraphAndDownloadClient(
      deltaPages: [
        _deltaPage([
          {
            'id': 'vid1',
            'name': 'clip.mp4',
            'file': {'mimeType': 'video/mp4'},
            '@microsoft.graph.downloadUrl': 'https://dl.example.com/vid',
            'webUrl': 'https://web/item',
            'video': {'duration': 12000},
            'createdBy': {
              'user': {'displayName': 'Alex'},
            },
          },
        ]),
      ],
    );
    final ctx = await _ctx(db, secrets);
    await OneDriveMediaDataProvider(httpClient: http).collect(ctx);
    final vids = await db.select(db.videos).get();
    expect(vids.length, 1);
    expect(vids.single.dataProvider, kMediaDataProviderOneDrive);
    expect(vids.single.durationSeconds, 12);
    expect(vids.single.photographerName, 'Alex');
    await db.close();
  });

  test('globalPerPollLimit stops second source', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      globalPerPoll: 1,
      accountsJson:
          '[{"graphAccountKey":"u","sources":['
          '{"path":"/a","kind":"photo","category":"c","maxFiles":10},'
          '{"path":"/b","kind":"photo","category":"c","maxFiles":10}'
          ']}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final http = _TwoFolderGraphClient();
    final ctx = await _ctx(db, secrets);
    await OneDriveMediaDataProvider(httpClient: http).collect(ctx);
    expect(http.graphGets, 2);
    expect((await db.select(db.photos).get()).length, 1);
    await db.close();
  });

  test('empty accounts performs no HTTP', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(db, accountsJson: '[]');
    final httpClient = _CountingClient();
    final ctx = await _ctx(db, InMemorySecretStore());
    final p = OneDriveMediaDataProvider(httpClient: httpClient);
    await p.collect(ctx);
    expect(httpClient.requests, 0);
    await db.close();
  });

  test('poll gate skips second collect within pollSeconds', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      pollSeconds: 3600,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    var clock = 10_000_000_000;
    final httpClient = _CountingClient();
    final ctx = await _ctx(db, secrets);
    final p = OneDriveMediaDataProvider(httpClient: httpClient, nowMs: () => clock);
    await p.collect(ctx);
    expect(httpClient.requests, greaterThan(0));
    final n1 = httpClient.requests;
    clock += 1000;
    await p.collect(ctx);
    expect(httpClient.requests, n1);
    clock = 10_000_000_000 + (3600 * 1000) + 1;
    await p.collect(ctx);
    expect(httpClient.requests, greaterThan(n1));
    await db.close();
  });

  test('downloads photos and stores rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/Pictures/F","kind":"photo","category":"fam","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final httpClient = _GraphAndDownloadClient(
      deltaPages: [
        _deltaPage([
          _drivePhoto('id1', 'https://dl.example.com/1'),
          _drivePhoto('id2', 'https://dl.example.com/2'),
        ]),
      ],
    );
    final ctx = await _ctx(db, secrets);
    final p = OneDriveMediaDataProvider(httpClient: httpClient);
    await p.collect(ctx);
    expect(httpClient.downloadGets, 2);
    final photos = await db.select(db.photos).get();
    expect(photos.length, 2);
    expect(photos.every((e) => e.dataProvider == kMediaDataProviderOneDrive), isTrue);
    expect(photos.every((e) => e.category == 'fam'), isTrue);
    expect(photos.every((e) => e.photographerName == 'Pat'), isTrue);
    await db.close();
  });

  test('perPollLimit caps downloads per collect', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10,"perPollLimit":1}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final httpClient = _GraphAndDownloadClient(
      deltaPages: [
        _deltaPage([
          _drivePhoto('a', 'https://dl.example.com/a'),
          _drivePhoto('b', 'https://dl.example.com/b'),
        ]),
      ],
    );
    final ctx = await _ctx(db, secrets);
    final p = OneDriveMediaDataProvider(httpClient: httpClient);
    await p.collect(ctx);
    expect(httpClient.downloadGets, 1);
    final photos = await db.select(db.photos).get();
    expect(photos.length, 1);
    await db.close();
  });

  test('prune removes oldest when over maxFiles', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":2}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );

    Future<void> insertPhoto(String graphItemId, DateTime fetched) async {
      final id = kOneDriveMediaItemRowId('u', graphItemId);
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: id,
              category: const Value('c'),
              dataProvider: const Value(kMediaDataProviderOneDrive),
              mediaBlobKey: 'onedrive/photo/$id/media',
              photographerName: '',
              photographerUrl: '',
              pexelsPageUrl: '',
              fetchedAtMs: fetched,
            ),
          );
    }

    await insertPhoto('old', DateTime.utc(2020));
    await insertPhoto('mid', DateTime.utc(2021));
    await insertPhoto('new', DateTime.utc(2022));

    final httpClient = _GraphAndDownloadClient(
      deltaPages: [_deltaPage([])],
    );
    final ctx = await _ctx(db, secrets);
    final p = OneDriveMediaDataProvider(httpClient: httpClient);
    await p.collect(ctx);

    final photos = await db.select(db.photos).get();
    expect(photos.length, 2);
    expect(
      photos.map((e) => e.id).contains(kOneDriveMediaItemRowId('u', 'old')),
      isFalse,
    );
    await db.close();
  });

  test('video source skips image mime items', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/v","kind":"video","category":"c","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final httpClient = _GraphAndDownloadClient(
      deltaPages: [
        _deltaPage([_drivePhoto('x', 'https://dl.example.com/x')]),
      ],
    );
    final ctx = await _ctx(db, secrets);
    final p = OneDriveMediaDataProvider(httpClient: httpClient);
    await p.collect(ctx);
    expect(httpClient.downloadGets, 0);
    expect(await db.select(db.videos).get(), isEmpty);
    await db.close();
  });

  test('kind both downloads photo and video', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/m","kind":"both","category":"mix","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final httpClient = _GraphAndDownloadClient(
      deltaPages: [
        _deltaPage([
          _drivePhoto('p1', 'https://dl.example.com/p'),
          {
            'id': 'v1',
            'name': 'c.mp4',
            'file': {'mimeType': 'video/mp4'},
            '@microsoft.graph.downloadUrl': 'https://dl.example.com/v',
            'webUrl': 'https://w/v',
            'video': {'duration': 5000},
            'createdBy': {
              'user': {'displayName': 'Sam'},
            },
          },
        ]),
      ],
    );
    final ctx = await _ctx(db, secrets);
    await OneDriveMediaDataProvider(httpClient: httpClient).collect(ctx);
    expect(httpClient.downloadGets, 2);
    expect((await db.select(db.photos).get()).length, 1);
    expect((await db.select(db.videos).get()).length, 1);
    await db.close();
  });

  test('delta deleted facet removes local photo', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/a","kind":"photo","category":"c","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    final goneId = kOneDriveMediaItemRowId('u', 'gone');
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: goneId,
            category: const Value('c'),
            dataProvider: const Value(kMediaDataProviderOneDrive),
            mediaBlobKey: 'onedrive/photo/$goneId/media',
            photographerName: '',
            photographerUrl: '',
            pexelsPageUrl: '',
            fetchedAtMs: DateTime.utc(2022),
          ),
        );

    final httpClient = _GraphAndDownloadClient(
      deltaPages: [
        _deltaPage([
          {'id': 'gone', 'deleted': <String, dynamic>{}},
        ]),
      ],
    );
    final ctx = await _ctx(db, secrets);
    await OneDriveMediaDataProvider(httpClient: httpClient).collect(ctx);
    expect(await db.select(db.photos).get(), isEmpty);
    await db.close();
  });

  test('persists deltaLink to config KV after sync', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedProvider(
      db,
      accountsJson:
          '[{"graphAccountKey":"u","sources":[{"path":"/z","kind":"photo","category":"c","maxFiles":10}]}]',
    );
    final secrets = InMemorySecretStore();
    await secrets.write(microsoftGraphAccessTokenSecret('u'), 'tok');
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kMicrosoftGraphAccessTokenExpiresAtKvKey('u'),
            value: '${DateTime.now().millisecondsSinceEpoch + 86400000 * 365}',
          ),
        );
    const persistedLink = 'https://graph.microsoft.com/v1.0/delta?token=persisted';
    final httpClient = _GraphAndDownloadClient(
      deltaPages: [
        {
          'value': <Object?>[],
          '@odata.deltaLink': persistedLink,
        },
      ],
    );
    final ctx = await _ctx(db, secrets);
    await OneDriveMediaDataProvider(httpClient: httpClient).collect(ctx);
    final key = kOneDriveMediaDeltaLinkKvKey('u', 'z');
    final row =
        await (db.select(db.configKeyValues)..where((t) => t.key.equals(key)))
            .getSingleOrNull();
    expect(row?.value, persistedLink);
    await db.close();
  });
}

Map<String, Object?> _drivePhoto(String id, String downloadUrl) => {
      'id': id,
      'name': '$id.jpg',
      'file': {'mimeType': 'image/jpeg'},
      '@microsoft.graph.downloadUrl': downloadUrl,
      'webUrl': 'https://example.com/item',
      'createdBy': {
        'user': {'displayName': 'Pat'},
      },
    };

Future<DataWriteContext> _ctx(
  AppDatabase db,
  InMemorySecretStore secrets, {
  String? clientId = 'test-ms-client-id',
}) async {
  if (clientId != null) {
    await secrets.write(kMicrosoftGraphClientIdSecretKey, clientId);
  }
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

Future<void> _seedProvider(
  AppDatabase db, {
  required String accountsJson,
  int pollSeconds = 0,
  int globalPerPoll = 50,
  bool enabled = true,
}) async {
  await db.into(db.integrations).insertOnConflictUpdate(
        IntegrationsCompanion.insert(
          id: kOneDriveMediaProviderId,
          integrationType: 'photo_onedrive',
          enabled: Value(enabled),
          pollSeconds: Value(pollSeconds),
          baseUrl: const Value('https://graph.microsoft.com/v1.0'),
          configJson: Value(
            '{"accounts":$accountsJson,"globalPerPollLimit":$globalPerPoll}',
          ),
        ),
      );
}

class _NullGraphOAuth extends MicrosoftGraphOAuth {
  _NullGraphOAuth({required super.httpClient, required super.nowMs});

  @override
  Future<String?> ensureAccessToken({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String graphAccountKey,
  }) async => null;
}

class _FixedTokenOAuth extends MicrosoftGraphOAuth {
  _FixedTokenOAuth({required super.httpClient, required super.nowMs});

  @override
  Future<String?> ensureAccessToken({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String graphAccountKey,
  }) async => 'tok';
}

class _ThrowingOAuth extends MicrosoftGraphOAuth {
  _ThrowingOAuth() : super(httpClient: http.Client(), nowMs: () => 0);

  @override
  Future<String?> ensureAccessToken({
    required AppDatabase db,
    required SecretStore secrets,
    required String clientId,
    required String graphAccountKey,
  }) async {
    throw StateError('ensureAccessToken should not run');
  }
}

class _ErrorJsonGraphClient extends http.BaseClient {
  int graphGets = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'graph.microsoft.com') {
      graphGets++;
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'error': {'code': 'accessDenied', 'message': 'no'},
            }),
          ),
        ),
        403,
        headers: {'Content-Type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value([]), 404);
  }
}

class _PagingGraphClient extends http.BaseClient {
  int graphGets = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'graph.microsoft.com') {
      if (u.queryParameters[r'$select'] == 'id,folder') {
        graphGets++;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(jsonEncode({'id': 'pf', 'folder': <String, dynamic>{}})),
          ),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      graphGets++;
      if (u.toString().contains('next-page-delta')) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'value': [
                  _drivePhoto('p2', 'https://dl.example.com/2'),
                ],
                '@odata.deltaLink': _testDeltaLink,
              }),
            ),
          ),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'value': [
                _drivePhoto('p1', 'https://dl.example.com/1'),
              ],
              '@odata.nextLink':
                  'https://graph.microsoft.com/v1.0/next-page-delta',
            }),
          ),
        ),
        200,
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (u.host == 'dl.example.com') {
      return http.StreamedResponse(Stream.value([9]), 200);
    }
    return http.StreamedResponse(Stream.value([]), 404);
  }
}

class _TwoFolderGraphClient extends http.BaseClient {
  int graphGets = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'graph.microsoft.com') {
      if (u.queryParameters[r'$select'] == 'id,folder') {
        graphGets++;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({'id': 'folderA', 'folder': <String, dynamic>{}}),
            ),
          ),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
      if (u.path.contains('/delta')) {
        graphGets++;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'value': [
                  _drivePhoto('only', 'https://dl.example.com/o'),
                ],
                '@odata.deltaLink': _testDeltaLink,
              }),
            ),
          ),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
    if (u.host == 'dl.example.com') {
      return http.StreamedResponse(Stream.value([1]), 200);
    }
    return http.StreamedResponse(Stream.value([]), 404);
  }
}

class _CountingClient extends http.BaseClient {
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'value': []}))),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  }
}

class _GraphAndDownloadClient extends http.BaseClient {
  _GraphAndDownloadClient({
    required List<Map<String, Object?>> deltaPages,
  }) : _deltaPages = deltaPages;

  final String folderId = 'folder1';
  final List<Map<String, Object?>> _deltaPages;
  int resolveGets = 0;
  int deltaGets = 0;
  int downloadGets = 0;

  int get graphGets => resolveGets + deltaGets;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.host == 'graph.microsoft.com') {
      if (u.queryParameters[r'$select'] == 'id,folder') {
        resolveGets++;
        return _json({'id': folderId, 'folder': <String, dynamic>{}});
      }
      if (u.path.contains('/delta')) {
        final idx = deltaGets;
        deltaGets++;
        if (idx >= _deltaPages.length) {
          return _json({
            'value': <Object?>[],
            '@odata.deltaLink': _testDeltaLink,
          });
        }
        return _json(_deltaPages[idx]);
      }
    }
    if (u.host == 'dl.example.com') {
      downloadGets++;
      return http.StreamedResponse(
        Stream.value(<int>[1, 2, 3]),
        200,
      );
    }
    return http.StreamedResponse(Stream.value([]), 404);
  }

  http.StreamedResponse _json(Object obj) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(obj))),
        200,
        headers: {'Content-Type': 'application/json'},
      );
}
