import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/calendar_google/google_oauth.dart';
import 'package:waddle_integrations/google_photos/google_photos_media_data_provider.dart';
import 'package:waddle_integrations/google_photos/google_photos_picker_api.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

class _PickerClient extends http.BaseClient {
  _PickerClient(this.onRequest);

  final http.Response Function(http.BaseRequest request) onRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = onRequest(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _MemoryBlobStore implements BlobStore {
  final _bytes = <String, List<int>>{};

  @override
  Future<void> delete(BlobRef ref) async {
    _bytes.removeWhere((k, _) => ref.storageKey.endsWith(k));
  }

  @override
  Future<List<int>> readBytes(BlobRef ref) async => const [];

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async {
    _bytes[logicalKey] = bytes;
    return BlobRef('sha/$logicalKey');
  }

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

AppDatabase _openDb() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Future<DataWriteContext> _ctx(AppDatabase db, InMemorySecretStore secrets) async {
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: _MemoryBlobStore(),
    secrets: secrets,
    resolve: resolver.resolve,
  );
}

void main() {
  test('ingests photo from picker session list', () async {
    const photoBytes = [0xFF, 0xD8, 0xFF];
    final db = _openDb();
    final secrets = InMemorySecretStore();
    await secrets.write(kGoogleClientIdSecretKey, 'test-client-id');
    await secrets.write(googleAccessTokenSecret('acct1'), 'access-token');
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'default_photo_google',
            integrationType: kPhotoGoogleIntegrationType,
            enabled: const Value(true),
            pollSeconds: const Value(0),
            configJson: const Value('''
{
  "globalPerPollLimit": 10,
  "accounts": [
    {
      "googleAccountKey": "acct1",
      "sources": [
        {
          "sourceId": "album1",
          "albumLabel": "Test",
          "albumSearchHint": "Test",
          "category": "general",
          "maxFiles": 50,
          "mediaItemIds": ["media-1"],
          "pickerSessionId": "session-1"
        }
      ]
    }
  ]
}
'''),
          ),
        );
    await db.into(db.integrationAccounts).insert(
          IntegrationAccountsCompanion.insert(
            id: 'acct1',
            accountType: 'google',
            label: const Value('Test Google'),
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    await IntegrationKvRepository(db).upsertAccount(
      accountId: 'acct1',
      key: kIntegrationAccessTokenExpiresAtKey,
      value: '${DateTime.now().millisecondsSinceEpoch + 86400000}',
      valueType: kIntegrationKvTypeIntMs,
    );

    final client = _PickerClient((request) {
      if (request.url.host == 'photospicker.googleapis.com' &&
          request.url.path == '/v1/mediaItems') {
        return http.Response(
          jsonEncode({
            'mediaItems': [
              {
                'id': 'media-1',
                'type': 'PHOTO',
                'mediaFile': {
                  'baseUrl': 'https://lh3.googleusercontent.com/p/test',
                  'mimeType': 'image/jpeg',
                  'filename': 'vacation.jpg',
                  'mediaFileMetadata': {'width': 800, 'height': 600},
                },
              },
            ],
          }),
          200,
        );
      }
      if (request.url.host.contains('googleusercontent.com')) {
        return http.Response.bytes(photoBytes, 200);
      }
      return http.Response('not found', 404);
    });

    final provider = GooglePhotosPhotosDataProvider(
      httpClient: client,
      oauth: GoogleOAuth(httpClient: client),
      pickerApi: GooglePhotosPickerApi(httpClient: client),
    );

    await provider.collect(await _ctx(db, secrets));

    final photos = await db.select(db.photos).get();
    expect(photos, hasLength(1));
    expect(photos.single.category, 'general');
    expect(photos.single.dataProvider, kMediaDataProviderPhotoGoogle);
    expect(photos.single.altText, 'vacation.jpg');
    await db.close();
  });
}
