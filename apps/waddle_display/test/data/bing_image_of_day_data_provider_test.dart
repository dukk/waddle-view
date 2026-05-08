import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_display/config/provider_config_resolver.dart';
import 'package:waddle_display/data/data_write_context.dart';
import 'package:waddle_display/data/providers/bing_image_of_day/bing_image_of_day_data_provider.dart';
import 'package:waddle_display/persistence/config_json_documentation.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/persistence/tables.dart';
import 'package:waddle_display/secrets/in_memory_secret_store.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

const _jpegBytes = <int>[0xFF, 0xD8, 0xFF, 0xD9];

http.StreamedResponse _jsonResponse(String body, {int code = 200}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    code,
    headers: {'content-type': 'application/json'},
  );
}

http.StreamedResponse _bytesResponse(List<int> bytes, {int code = 200}) {
  return http.StreamedResponse(Stream.value(bytes), code);
}

Map<String, dynamic> _archiveImage({
  String startdate = '20260507',
  String urlbase = '/th?id=OHR.Test_EN-US000',
  String title = 'Desert wide',
  String copyright = 'Refuge (© Cam Example/Getty Images)',
  String copyrightlink = 'https://www.bing.com/search?q=test',
}) => {
  'startdate': startdate,
  'urlbase': urlbase,
  'title': title,
  'copyright': copyright,
  'copyrightlink': copyrightlink,
};

Future<void> _insertBingProvider(
  AppDatabase db, {
  bool enabled = true,
  int pollSeconds = 0,
  String configJson = '{"retentionDays":1,"market":"en-US","resolution":"UHD","category":"bing"}',
  String baseUrl = 'https://www.bing.com',
}) async {
  final doc = providerConfigJsonDocForType('bing_iotd');
  await db.into(db.providerSettings).insert(
    ProviderSettingsCompanion.insert(
      id: kBingImageOfDayProviderId,
      providerType: kBingImageOfDayProviderId,
      enabled: Value(enabled),
      pollSeconds: Value(pollSeconds),
      baseUrl: Value(baseUrl),
      configJson: Value(configJson),
      configJsonSchema: Value(doc.schema),
      exampleConfigJson: Value(doc.example),
    ),
  );
}

void _expectBingHeaders(http.BaseRequest request, String referer) {
  expect(request.headers['referer'], referer);
  expect(
    request.headers['user-agent'],
    kBingWallpaperUserAgent,
  );
}

void main() {
  test('buildBingWallpaperImageUrl joins base, urlbase, resolution', () {
    expect(
      buildBingWallpaperImageUrl(
        'https://www.bing.com',
        '/th?id=OHR.X_EN-US1',
        'UHD',
      ),
      'https://www.bing.com/th?id=OHR.X_EN-US1_UHD.jpg',
    );
  });

  test('collect skips when disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db, enabled: false);
    final requests = <http.BaseRequest>[];
    final client = _CaptureClient(requests, _ThrowClient());
    final provider = BingImageOfDayDataProvider(httpClient: client);
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);
    expect(requests, isEmpty);
    await db.close();
  });

  test('poll gate skips before interval', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db, pollSeconds: 3600);
    await db.into(db.configKeyValues).insert(
      ConfigKeyValuesCompanion.insert(
        key: kBingImageOfDayLastCollectKvKey,
        value: '1000000',
      ),
    );
    final requests = <http.BaseRequest>[];
    final provider = BingImageOfDayDataProvider(
      httpClient: _CaptureClient(requests, _ThrowClient()),
      nowMs: () => 1000000 + 500,
    );
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);
    expect(requests, isEmpty);
    await db.close();
  });

  test('happy path: headers, image URL, insert row and blob', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db);
    final requests = <http.BaseRequest>[];
    final inner = _RoutingBingClient(
      archiveJson: jsonEncode({'images': [_archiveImage()]}),
      imageBytes: _jpegBytes,
    );
    final client = _CaptureClient(requests, inner);
    final blobs = FakeBlobStore();
    final secrets = InMemorySecretStore();
    final provider = BingImageOfDayDataProvider(httpClient: client);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: blobs,
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);

    expect(requests.length, 2);
    _expectBingHeaders(requests[0], 'https://www.bing.com');
    expect(requests[0].url.path, '/HPImageArchive.aspx');
    expect(requests[0].url.queryParameters['mkt'], 'en-US');

    _expectBingHeaders(requests[1], 'https://www.bing.com');
    expect(
      requests[1].url.toString(),
      'https://www.bing.com/th?id=OHR.Test_EN-US000_UHD.jpg',
    );

    final row = await (db.select(db.photos)
          ..where((t) => t.id.equals('bing_20260507_en-US')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.dataProvider, kMediaDataProviderBing);
    expect(row.category, 'bing');
    expect(row.pexelsPageUrl, 'https://www.bing.com/search?q=test');
    expect(row.altText, 'Desert wide');
    expect(row.photographerName, 'Cam Example/Getty Images');
    expect(row.photographerUrl, '');

    final kv = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kBingImageOfDayLastCollectKvKey)))
        .getSingleOrNull();
    expect(kv, isNotNull);
    expect(kv!.value.isNotEmpty, isTrue);

    await db.close();
  });

  test('idempotent: second collect does not re-download image', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db);
    final requests = <http.BaseRequest>[];
    final inner = _RoutingBingClient(
      archiveJson: jsonEncode({'images': [_archiveImage()]}),
      imageBytes: _jpegBytes,
    );
    final client = _CaptureClient(requests, inner);
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    final provider = BingImageOfDayDataProvider(httpClient: client);
    await provider.collect(ctx);
    expect(requests.length, 2);
    requests.clear();
    await provider.collect(ctx);
    expect(requests.length, 1);
    expect(requests.single.url.path, '/HPImageArchive.aspx');
    final count =
        await (db.select(db.photos)
              ..where((t) => t.id.equals('bing_20260507_en-US')))
            .get();
    expect(count.length, 1);
    await db.close();
  });

  test('retention prunes old bing_iotd photos', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db);
    const oldKey = 'bing_iotd/bing_20200101_en-US/image';
    await db.into(db.blobMetadata).insert(
      BlobMetadataCompanion.insert(
        blobKey: oldKey,
        sha256: 'deadbeef',
        relativePath: 'deadbeef_path',
        bytes: 4,
        mimeType: const Value('image/jpeg'),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    await db.into(db.photos).insert(
      PhotosCompanion.insert(
        id: 'bing_20200101_en-US',
        category: const Value('bing'),
        dataProvider: const Value(kMediaDataProviderBing),
        mediaBlobKey: oldKey,
        photographerName: 'x',
        photographerUrl: '',
        pexelsPageUrl: '',
        altText: const Value(''),
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch -
              const Duration(hours: 36).inMilliseconds,
        ),
      ),
    );

    final requests = <http.BaseRequest>[];
    final inner = _RoutingBingClient(
      archiveJson: jsonEncode({'images': [_archiveImage()]}),
      imageBytes: _jpegBytes,
    );
    final client = _CaptureClient(requests, inner);
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await BingImageOfDayDataProvider(httpClient: client).collect(ctx);

    final old = await (db.select(db.photos)
          ..where((t) => t.id.equals('bing_20200101_en-US')))
        .getSingleOrNull();
    expect(old, isNull);
    final neu = await (db.select(db.photos)
          ..where((t) => t.id.equals('bing_20260507_en-US')))
        .getSingleOrNull();
    expect(neu, isNotNull);
    await db.close();
  });

  test('archive 500 does not throw and leaves no new photo', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db);
    final client = _RoutingBingClient(
      archiveStatus: 500,
      archiveJson: '{}',
      imageBytes: _jpegBytes,
    );
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await BingImageOfDayDataProvider(httpClient: client).collect(ctx);
    final rows = await db.select(db.photos).get();
    expect(rows.where((r) => r.id.startsWith('bing_')), isEmpty);
    await db.close();
  });

  test('empty image body skips insert', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db);
    final client = _RoutingBingClient(
      archiveJson: jsonEncode({'images': [_archiveImage()]}),
      imageBytes: const [],
    );
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await BingImageOfDayDataProvider(httpClient: client).collect(ctx);
    final row = await (db.select(db.photos)
          ..where((t) => t.id.equals('bing_20260507_en-US')))
        .getSingleOrNull();
    expect(row, isNull);
    await db.close();
  });

  test('custom resolution and market', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(
      db,
      configJson:
          '{"retentionDays":1,"market":"en-GB","resolution":"1920x1080","category":"bing"}',
    );
    final requests = <http.BaseRequest>[];
    final inner = _RoutingBingClient(
      archiveJson: jsonEncode({
        'images': [
          _archiveImage(startdate: '20260508'),
        ],
      }),
      imageBytes: _jpegBytes,
    );
    final client = _CaptureClient(requests, inner);
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await BingImageOfDayDataProvider(httpClient: client).collect(ctx);
    expect(requests[0].url.queryParameters['mkt'], 'en-GB');
    expect(
      requests[1].url.toString(),
      contains('_1920x1080.jpg'),
    );
    final row = await (db.select(db.photos)
          ..where((t) => t.id.equals('bing_20260508_en-GB')))
        .getSingleOrNull();
    expect(row, isNotNull);
    await db.close();
  });

  test('archive GET times out without hanging', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _insertBingProvider(db);
    final hang = _HangingStreamClient(onlyArchive: true);
    final secrets = InMemorySecretStore();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await BingImageOfDayDataProvider(
      httpClient: hang,
      requestTimeout: const Duration(milliseconds: 50),
    ).collect(ctx);
    final rows = await db.select(db.photos).get();
    expect(rows.where((r) => r.dataProvider == kMediaDataProviderBing), isEmpty);
    await db.close();
  });
}

class _CaptureClient extends http.BaseClient {
  _CaptureClient(this.recorded, this.inner);
  final List<http.BaseRequest> recorded;
  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    recorded.add(request);
    return inner.send(request);
  }
}

class _ThrowClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw StateError('unexpected');
  }
}

class _RoutingBingClient extends http.BaseClient {
  _RoutingBingClient({
    this.archiveStatus = 200,
    required this.archiveJson,
    required this.imageBytes,
    this.imageStatus = 200,
  });

  final int archiveStatus;
  final String archiveJson;
  final List<int> imageBytes;
  final int imageStatus;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (u.path.contains('HPImageArchive')) {
      return _jsonResponse(archiveJson, code: archiveStatus);
    }
    return _bytesResponse(imageBytes, code: imageStatus);
  }
}

class _HangingStreamClient extends http.BaseClient {
  _HangingStreamClient({required this.onlyArchive});
  final bool onlyArchive;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final u = request.url;
    if (onlyArchive && u.path.contains('HPImageArchive')) {
      final c = StreamController<List<int>>();
      return http.StreamedResponse(c.stream, 200);
    }
    return _jsonResponse('{}');
  }
}
