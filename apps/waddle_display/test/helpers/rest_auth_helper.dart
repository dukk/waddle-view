import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/http_tls.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_display/debug/operator_telemetry_hub.dart';
import 'package:waddle_display/display/display_navigation_bus.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';
import 'package:waddle_shared/auth/adoption_crypto.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/auth/cors_origin_repository.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/db_encrypted_secret_store.dart';
import 'package:waddle_shared/secrets/platform/in_memory_dek_protector.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import 'fake_blob_store.dart';
import 'adoption_test_helpers.dart';
import 'memory_database.dart';

/// Boots a REST server with an adopted API key for integration tests.
class RestTestHarness {
  RestTestHarness._({
    required this.db,
    required this.server,
    required this.apiKey,
    required this.adoption,
    required this.corsOrigins,
    required this.blobs,
    required this.secrets,
    required this.instanceId,
    required this.identifier,
    required this.role,
  });

  final AppDatabase db;
  final LocalRestServer server;
  final String apiKey;
  final AdoptionRepository adoption;
  final CorsOriginRepository corsOrigins;
  final BlobStore blobs;
  final SecretStore secrets;
  final String instanceId;
  final String identifier;
  final String role;

  String get baseUrl => server.baseUrl;

  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  static Future<RestTestHarness> start({
    String role = kUserRoleAdmin,
    String identifier = 'test-client',
    String instanceId = 'test-instance-id-for-rest-harness-012345',
    String apiKey = 'test-rest-harness-api-key',
    OperatorTelemetryHub? telemetryHub,
    DisplayNavigationBus? navigationBus,
    AppDatabase? database,
    Future<void> Function()? onConfigChanged,
    List<String> seedCorsOrigins = const [],
    Map<String, String> env = const {},
    FakeBlobStore? blobStore,
  }) async {
    return startWithApiKey(
      apiKey: apiKey,
      role: role,
      identifier: identifier,
      instanceId: instanceId,
      database: database,
      telemetryHub: telemetryHub,
      navigationBus: navigationBus,
      onConfigChanged: onConfigChanged,
      seedCorsOrigins: seedCorsOrigins,
      env: env,
      blobStore: blobStore,
    );
  }

  /// Boots a server and completes adoption over HTTP (request + confirm).
  static Future<RestTestHarness> startViaAdoption({
    String role = kUserRoleAdmin,
    String identifier = 'test-client',
    String instanceId = 'test-instance-id-for-rest-harness-012345',
    String? adoptionOrigin = 'http://127.0.0.1:5173',
    OperatorTelemetryHub? telemetryHub,
    DisplayNavigationBus? navigationBus,
    AppDatabase? database,
    Future<void> Function()? onConfigChanged,
    Map<String, String> env = const {},
    FakeBlobStore? blobStore,
  }) async {
    final db = database ?? openMemoryDatabase();
    if (database == null) {
      await warmDatabase(db);
    }
    final built = await _buildServer(
      db: db,
      instanceId: instanceId,
      env: env,
      telemetryHub: telemetryHub,
      navigationBus: navigationBus,
      onConfigChanged: onConfigChanged,
      seedCorsOrigins: const [],
      blobStore: blobStore,
    );

    final adoptionHeaders = <String, String>{
      'Content-Type': 'application/json',
      if (adoptionOrigin != null) ...{
        'Origin': adoptionOrigin,
        'Referer': '$adoptionOrigin/',
      },
    };

    final requestRes = await http.post(
      Uri.parse('${built.server.baseUrl}/v1/adoption/request'),
      headers: adoptionHeaders,
      body: jsonEncode({'identifier': identifier, 'role': role}),
    );
    if (requestRes.statusCode != 200) {
      throw StateError(
        'adoption request failed: ${requestRes.statusCode} ${requestRes.body}',
      );
    }
    final requestBody = jsonDecode(requestRes.body) as Map<String, dynamic>;
    if (requestBody.containsKey('challenge_code')) {
      throw StateError('adoption request must not return challenge_code');
    }
    final alerts = await db.select(db.alerts).get();
    final adoptionAlert = alerts.lastWhere((r) => r.source == kAdoptionAlertSource);
    final challengeCode = adoptionChallengeFromAlertBody(adoptionAlert.body);

    final confirmRes = await http.post(
      Uri.parse('${built.server.baseUrl}/v1/adoption/confirm'),
      headers: adoptionHeaders,
      body: jsonEncode({
        'identifier': identifier,
        'challenge_code': challengeCode,
      }),
    );
    if (confirmRes.statusCode != 200) {
      throw StateError(
        'adoption confirm failed: ${confirmRes.statusCode} ${confirmRes.body}',
      );
    }
    final confirmBody = jsonDecode(confirmRes.body) as Map<String, dynamic>;
    final apiKey = confirmBody['api_key'] as String;

    return RestTestHarness._(
      db: db,
      server: built.server,
      apiKey: apiKey,
      adoption: built.adoption,
      corsOrigins: built.corsOrigins,
      blobs: built.blobs,
      secrets: built.secrets,
      instanceId: instanceId,
      identifier: identifier,
      role: role,
    );
  }

  /// Inserts an API client without running the adoption HTTP flow.
  static Future<RestTestHarness> startWithApiKey({
    required String apiKey,
    String role = kUserRoleAdmin,
    String identifier = 'test-client',
    String instanceId = 'test-instance-id-for-rest-harness-012345',
    AppDatabase? database,
    OperatorTelemetryHub? telemetryHub,
    DisplayNavigationBus? navigationBus,
    Future<void> Function()? onConfigChanged,
    List<String> seedCorsOrigins = const [],
    Map<String, String> env = const {},
    FakeBlobStore? blobStore,
  }) async {
    final db = database ?? openMemoryDatabase();
    if (database == null) {
      await warmDatabase(db);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.apiClients).insert(
      ApiClientsCompanion.insert(
        id: 'client_test',
        identifier: identifier,
        role: role,
        apiKeyHash: hashAdoptionApiKey(apiKey),
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    final built = await _buildServer(
      db: db,
      instanceId: instanceId,
      env: env,
      telemetryHub: telemetryHub,
      navigationBus: navigationBus,
      onConfigChanged: onConfigChanged,
      seedCorsOrigins: seedCorsOrigins,
      blobStore: blobStore,
    );
    return RestTestHarness._(
      db: db,
      server: built.server,
      apiKey: apiKey,
      adoption: built.adoption,
      corsOrigins: built.corsOrigins,
      blobs: built.blobs,
      secrets: built.secrets,
      instanceId: instanceId,
      identifier: identifier,
      role: role,
    );
  }

  static Future<
      ({
        LocalRestServer server,
        AdoptionRepository adoption,
        CorsOriginRepository corsOrigins,
        BlobStore blobs,
        SecretStore secrets,
      })> _buildServer({
    required AppDatabase db,
    required String instanceId,
    required Map<String, String> env,
    OperatorTelemetryHub? telemetryHub,
    DisplayNavigationBus? navigationBus,
    Future<void> Function()? onConfigChanged,
    required List<String> seedCorsOrigins,
    FakeBlobStore? blobStore,
  }) async {
    final adoption = AdoptionRepository(db, instanceId: instanceId);
    final corsOrigins = CorsOriginRepository(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (seedCorsOrigins.isNotEmpty) {
      await corsOrigins.seedEnvOrigins(seedCorsOrigins, nowMs: now);
    }
    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    final blobs = blobStore ?? FakeBlobStore();
    final secrets = DbEncryptedSecretStore(
      db: db,
      protector: InMemoryDekProtector(),
    );
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      adoption: adoption,
      corsOrigins: corsOrigins,
      ticker: ticker,
      blobs: blobs,
      secrets: secrets,
      onConfigChanged: onConfigChanged ?? () async {},
      env: env,
      telemetryHub: telemetryHub,
      navigationBus: navigationBus,
    );
    final server = await LocalRestServer.bind(
      handler: handler,
      port: 0,
      tls: const HttpTlsConfig(enabled: false),
    );
    return (
      server: server,
      adoption: adoption,
      corsOrigins: corsOrigins,
      blobs: blobs,
      secrets: secrets,
    );
  }

  Future<void> dispose() async {
    await server.close();
    await db.close();
  }
}
