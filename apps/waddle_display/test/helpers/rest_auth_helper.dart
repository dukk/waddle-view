import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;
import 'package:waddle_display/alerts/drift_alert_repository.dart';
import 'package:waddle_display/api/local_rest_server.dart';
import 'package:waddle_display/debug/operator_telemetry_hub.dart';
import 'package:waddle_display/display/display_navigation_bus.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';
import 'package:waddle_shared/auth/password_hash.dart';
import 'package:waddle_shared/auth/user_repository.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import 'memory_database.dart';

/// Boots a REST server with an admin session for integration tests.
class RestTestHarness {
  RestTestHarness._({
    required this.db,
    required this.server,
    required this.token,
    required this.users,
  });

  final AppDatabase db;
  final LocalRestServer server;
  final String token;
  final UserRepository users;

  String get baseUrl => server.baseUrl;

  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  static Future<RestTestHarness> start({
    String role = kUserRoleAdmin,
    String password = 'test-password-12',
    String username = 'testadmin',
    OperatorTelemetryHub? telemetryHub,
    DisplayNavigationBus? navigationBus,
    AppDatabase? database,
    Future<void> Function()? onConfigChanged,
    List<String> corsAllowedOrigins = const [],
    Map<String, String> env = const {},
  }) async {
    final db = database ?? openMemoryDatabase();
    if (database == null) {
      await warmDatabase(db);
    }
    final users = UserRepository(db);
    final existing = await users.findByUsername(username);
    if (existing == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'user_test_admin',
          username: username,
          usernameLower: username.toLowerCase(),
          displayName: 'Test Admin',
          role: role,
          passwordHash: Value(hashPassword(password)),
          isBootstrap: const Value(false),
          createdAtMs: now,
          updatedAtMs: now,
        ),
      );
    }
    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      users: users,
      ticker: ticker,
      onConfigChanged: onConfigChanged ?? () async {},
      env: env,
      telemetryHub: telemetryHub,
      navigationBus: navigationBus,
      corsAllowedOrigins: corsAllowedOrigins,
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    final loginRes = await http.post(
      Uri.parse('${server.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (loginRes.statusCode != 200) {
      throw StateError('login failed: ${loginRes.statusCode} ${loginRes.body}');
    }
    final body = jsonDecode(loginRes.body) as Map<String, dynamic>;
    final token = body['session_token'] as String;
    return RestTestHarness._(
      db: db,
      server: server,
      token: token,
      users: users,
    );
  }

  Future<void> dispose() async {
    await server.close();
    await db.close();
  }
}

/// Harness with bootstrap `display` user (instance id password).
class BootstrapRestTestHarness {
  BootstrapRestTestHarness._({
    required this.db,
    required this.server,
    required this.token,
    required this.instanceId,
    required this.users,
  });

  final AppDatabase db;
  final LocalRestServer server;
  final String token;
  final String instanceId;
  final UserRepository users;

  String get baseUrl => server.baseUrl;

  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer $token',
  };

  static Future<BootstrapRestTestHarness> start({
    String instanceId = 'bootstrap-instance-id-hex',
  }) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final users = UserRepository(db);
    await users.ensureBootstrapUser(instanceIdPassword: instanceId);
    final alerts = DriftAlertRepository(db);
    final ticker = MemoryTickerCuratedRepository();
    final handler = buildRootHandler(
      db: db,
      alerts: alerts,
      users: users,
      ticker: ticker,
      onConfigChanged: () async {},
      env: const {},
    );
    final server = await LocalRestServer.bind(handler: handler, port: 0);
    final loginRes = await http.post(
      Uri.parse('${server.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': kBootstrapUsername,
        'password': instanceId,
      }),
    );
    final body = jsonDecode(loginRes.body) as Map<String, dynamic>;
    return BootstrapRestTestHarness._(
      db: db,
      server: server,
      token: body['session_token'] as String,
      instanceId: instanceId,
      users: users,
    );
  }

  Future<void> dispose() async {
    await server.close();
    await db.close();
  }
}
