import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/photo_nasa_earth_imagery/earth_imagery_data_provider.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/integration_config_json.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

class _EarthClient extends http.BaseClient {
  _EarthClient(this.onRequest);

  final http.Response Function(Uri uri) onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = onRequest(request.url);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _MemoryBlobStore implements BlobStore {
  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  Future<List<int>> readBytes(BlobRef ref) async => const [];

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async =>
      BlobRef(logicalKey);

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

void main() {
  test('collect stores earth imagery for default location', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await db.customStatement('select 1');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: kDefaultPhotoNasaEarthImageryIntegrationId,
            integrationType: kPhotoNasaEarthImageryIntegrationType,
            pollSeconds: const Value(0),
            enabled: const Value(true),
            configJson: Value(
              mergeBaseUrlIntoIntegrationConfig(
                '{"category":"nasa_earth","lookbackDays":16}',
                'https://api.nasa.gov',
              ),
            ),
          ),
        );
    await db.into(db.contentCategories).insertOnConflictUpdate(
          ContentCategoriesCompanion.insert(
            id: 'nasa_earth',
            label: 'NASA Earth',
          ),
        );

    final secrets = InMemorySecretStore();
    await secrets.write(
      providerAccessTokenSecretKey(kDefaultPhotoNasaEarthImageryIntegrationId),
      'KEY',
    );

    const jpeg = <int>[0xFF, 0xD8, 0xFF, 0xD9];
    final client = _EarthClient((uri) {
      if (uri.path == '/planetary/earth/assets') {
        return http.Response(
          jsonEncode({
            'results': [
              {'date': '2026-05-20T00:00:00', 'id': 'asset1'},
            ],
          }),
          200,
        );
      }
      if (uri.path == '/planetary/earth/imagery') {
        return http.Response(
          jsonEncode({'url': 'https://api.nasa.gov/fake-tile.jpg'}),
          200,
        );
      }
      return http.Response.bytes(jpeg, 200);
    });

    final provider = NasaEarthImageryDataProvider(
      httpClient: client,
      nowUtc: () => DateTime.utc(2026, 5, 21),
    );
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemoryBlobStore(),
      secrets: secrets,
      resolve: ProviderConfigResolver(db, secrets).resolve,
    );
    await provider.collect(ctx);

    final row = await (db.select(db.photos)
          ..where((t) => t.id.equals('earth_default_2026-05-20')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.dataProvider, kMediaDataProviderPhotoNasaEarthImagery);
    await db.close();
  });
}
