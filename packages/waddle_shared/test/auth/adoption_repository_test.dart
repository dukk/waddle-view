import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/auth/adoption_crypto.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/config/adoption.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  const instanceId = 'instance-id-for-adoption-tests-0123456789ab';

  late AppDatabase db;
  late AdoptionRepository repo;
  var alertCounter = 0;
  final dismissedAlerts = <int>[];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AdoptionRepository(db, instanceId: instanceId);
    alertCounter = 0;
    dismissedAlerts.clear();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertAlert({
    required String title,
    required String body,
    required int expiresAtMs,
  }) async {
    alertCounter += 1;
    return alertCounter;
  }

  Future<void> dismissAlert(int alertId) async {
    dismissedAlerts.add(alertId);
  }

  test('startRequest and confirm issues api key', () async {
    const now = 1_000_000;
    final started = await repo.startRequest(
      identifier: 'controller-1',
      role: kUserRoleOperator,
      insertAlert: insertAlert,
      nowMs: now,
    );
    expect(started.challengeCode.length, 8);

    final confirmed = await repo.confirm(
      identifier: 'controller-1',
      challengeCode: started.challengeCode,
      nowMs: now + 1000,
      dismissAlert: dismissAlert,
    );
    expect(confirmed, isNotNull);
    expect(confirmed!.role, kUserRoleOperator);
    expect(confirmed.permissions, isNotEmpty);

    final client = await repo.clientForApiKey(confirmed.apiKey);
    expect(client?.identifier, 'controller-1');
    expect(client?.role, kUserRoleOperator);
    expect(dismissedAlerts, contains(started.alertId));
  });

  test('confirm rejects wrong challenge', () async {
    const now = 2_000_000;
    await repo.startRequest(
      identifier: 'x',
      role: kUserRoleViewer,
      insertAlert: insertAlert,
      nowMs: now,
    );
    final confirmed = await repo.confirm(
      identifier: 'x',
      challengeCode: 'WRONG123',
      nowMs: now + 1000,
      dismissAlert: dismissAlert,
    );
    expect(confirmed, isNull);
  });

  test('confirm rejects expired pending', () async {
    const now = 3_000_000;
    final started = await repo.startRequest(
      identifier: 'expired',
      role: kUserRoleAdmin,
      insertAlert: insertAlert,
      nowMs: now,
    );
    final confirmed = await repo.confirm(
      identifier: 'expired',
      challengeCode: started.challengeCode,
      nowMs: now + kAdoptionChallengeTtlMs + 1,
      dismissAlert: dismissAlert,
    );
    expect(confirmed, isNull);
  });

  test('re-adopt same identifier rotates api key', () async {
    const now = 4_000_000;
    final first = await repo.startRequest(
      identifier: 'rotate',
      role: kUserRoleOperator,
      insertAlert: insertAlert,
      nowMs: now,
    );
    final firstConfirm = await repo.confirm(
      identifier: 'rotate',
      challengeCode: first.challengeCode,
      nowMs: now + 1,
      dismissAlert: dismissAlert,
    );

    final second = await repo.startRequest(
      identifier: 'rotate',
      role: kUserRoleOperator,
      insertAlert: insertAlert,
      nowMs: now + 10_000,
    );
    final secondConfirm = await repo.confirm(
      identifier: 'rotate',
      challengeCode: second.challengeCode,
      nowMs: now + 10_001,
      dismissAlert: dismissAlert,
    );

    expect(firstConfirm!.apiKey, isNot(secondConfirm!.apiKey));
    expect(await repo.clientForApiKey(firstConfirm.apiKey), isNull);
    final rotated = await repo.clientForApiKey(secondConfirm.apiKey);
    expect(rotated?.identifier, 'rotate');
  });

  test('listClients returns masked keys sorted by createdAtMs desc', () async {
    const now = 5_000_000;
    await repo.grantInstant(
      identifier: 'older',
      role: kUserRoleViewer,
      nowMs: now,
    );
    await repo.grantInstant(
      identifier: 'newer',
      role: kUserRoleAdmin,
      nowMs: now + 10_000,
    );

    final items = await repo.listClients();
    expect(items.length, 2);
    expect(items.first.identifier, 'newer');
    expect(items.first.maskedApiKey, startsWith(kAdoptionApiKeyPrefix));
    expect(items.first.maskedApiKey, contains('••••'));
  });

  test('revokeClient removes client', () async {
    const now = 6_000_000;
    final granted = await repo.grantInstant(
      identifier: 'revoke-me',
      role: kUserRoleOperator,
      nowMs: now,
    );
    final listed = await repo.listClients();
    final id = listed.single.id;

    expect(await repo.revokeClient(id), isTrue);
    expect(await repo.clientForApiKey(granted.apiKey), isNull);
    expect(await repo.revokeClient(id), isFalse);
  });

  test('maskAdoptionApiKeyHash is stable', () {
    final masked = maskAdoptionApiKeyHash('abc123xyz');
    expect(masked, startsWith(kAdoptionApiKeyPrefix));
    expect(masked, endsWith('xyz'));
    expect(masked, contains('••••'));
  });
}
