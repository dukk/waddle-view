import 'package:drift/drift.dart';

import '../config/adoption.dart';
import '../persistence/database.dart';
import 'adoption_challenge_format.dart';
import 'adoption_crypto.dart';
import 'role_permissions.dart';

/// Result of starting an adoption challenge.
class AdoptionRequestResult {
  const AdoptionRequestResult({
    required this.challengeCode,
    required this.expiresAtMs,
    required this.identifier,
    required this.role,
    required this.alertId,
  });

  final String challengeCode;
  final int expiresAtMs;
  final String identifier;
  final String role;
  final int alertId;
}

/// Confirmed adoption with a new API key.
class AdoptionConfirmResult {
  const AdoptionConfirmResult({
    required this.apiKey,
    required this.identifier,
    required this.role,
    required this.permissions,
  });

  final String apiKey;
  final String identifier;
  final String role;
  final List<String> permissions;
}

/// Adopted client row for API key middleware.
class ApiClientRecord {
  const ApiClientRecord({
    required this.id,
    required this.identifier,
    required this.role,
    required this.apiKeyHash,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String identifier;
  final String role;
  final String apiKeyHash;
  final int createdAtMs;
  final int updatedAtMs;
}

/// API client row for operator listing (key shown masked from hash only).
class ApiClientListItem {
  const ApiClientListItem({
    required this.id,
    required this.identifier,
    required this.role,
    required this.maskedApiKey,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String identifier;
  final String role;
  final String maskedApiKey;
  final int createdAtMs;
  final int updatedAtMs;
}

class AdoptionRepository {
  AdoptionRepository(this._db, {required String instanceId})
      : _instanceId = instanceId;

  final AppDatabase _db;
  final String _instanceId;

  Future<AdoptionRequestResult> startRequest({
    required String identifier,
    required String role,
    required Future<int> Function({
      required String title,
      required String body,
      required int expiresAtMs,
    }) insertAlert,
    required int nowMs,
  }) async {
    await sweepExpiredPending(nowMs: nowMs);
    await _cancelPendingForIdentifier(identifier, nowMs: nowMs);

    final issuedAtMs = nowMs;
    final expiresAtMs = nowMs + kAdoptionChallengeTtlMs;
    final nonce = generateAdoptionNonce();
    final challengeCode = deriveAdoptionChallengeCode(
      instanceId: _instanceId,
      identifier: identifier,
      issuedAtMs: issuedAtMs,
      nonce: nonce,
    );
    final challengeHash = hashAdoptionChallengeCode(challengeCode);

    final roleLabel = adoptionRoleDisplayLabel(role);
    final formattedCode = formatAdoptionChallengeCode(challengeCode);
    final body =
        'Client "$identifier" is requesting $roleLabel access.\n\n'
        'Challenge code: $formattedCode';
    final alertId = await insertAlert(
      title: 'Adopt display',
      body: body,
      expiresAtMs: expiresAtMs,
    );

    final pendingId = 'adopt_${issuedAtMs}_$nonce';
    await _db.into(_db.adoptionPending).insert(
          AdoptionPendingCompanion.insert(
            id: pendingId,
            identifier: identifier,
            role: role,
            issuedAtMs: issuedAtMs,
            expiresAtMs: expiresAtMs,
            challengeHash: challengeHash,
            nonce: nonce,
            alertId: Value(alertId),
          ),
        );

    return AdoptionRequestResult(
      challengeCode: challengeCode,
      expiresAtMs: expiresAtMs,
      identifier: identifier,
      role: role,
      alertId: alertId,
    );
  }

  Future<AdoptionConfirmResult?> confirm({
    required String identifier,
    required String challengeCode,
    required int nowMs,
    required Future<void> Function(int alertId) dismissAlert,
    String? referrerOrigin,
  }) async {
    await sweepExpiredPending(nowMs: nowMs, dismissAlert: dismissAlert);

    final pending = await (_db.select(_db.adoptionPending)
          ..where((t) => t.identifier.equals(identifier)))
        .getSingleOrNull();
    if (pending == null) {
      return null;
    }
    if (pending.expiresAtMs <= nowMs) {
      await _deletePending(pending, dismissAlert: dismissAlert);
      return null;
    }

    final submittedHash = hashAdoptionChallengeCode(challengeCode);
    if (!constantTimeStringEquals(submittedHash, pending.challengeHash)) {
      return null;
    }

    final result = await _issueApiKey(
      identifier: identifier,
      role: pending.role,
      challengeCode: challengeCode,
      nowMs: nowMs,
      referrerOrigin: referrerOrigin,
    );

    await _deletePending(pending, dismissAlert: dismissAlert);

    return result;
  }

  /// Admin-only: issue an API key without a kiosk challenge.
  Future<AdoptionConfirmResult> grantInstant({
    required String identifier,
    required String role,
    required int nowMs,
    String? referrerOrigin,
  }) async {
    final nonce = generateAdoptionNonce();
    final challengeCode = deriveAdoptionChallengeCode(
      instanceId: _instanceId,
      identifier: identifier,
      issuedAtMs: nowMs,
      nonce: nonce,
    );
    return _issueApiKey(
      identifier: identifier,
      role: role,
      challengeCode: challengeCode,
      nowMs: nowMs,
      referrerOrigin: referrerOrigin,
    );
  }

  Future<AdoptionConfirmResult> _issueApiKey({
    required String identifier,
    required String role,
    required String challengeCode,
    required int nowMs,
    String? referrerOrigin,
  }) async {
    final apiKey = deriveAdoptionApiKey(
      instanceId: _instanceId,
      challengeCode: challengeCode,
      identifier: identifier,
    );
    final apiKeyHash = hashAdoptionApiKey(apiKey);

    final existing = await (_db.select(_db.apiClients)
          ..where((t) => t.identifier.equals(identifier)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.apiClients)..where((t) => t.id.equals(existing.id)))
          .write(
        ApiClientsCompanion(
          role: Value(role),
          apiKeyHash: Value(apiKeyHash),
          referrerOrigin: Value(referrerOrigin),
          updatedAtMs: Value(nowMs),
        ),
      );
    } else {
      await _db.into(_db.apiClients).insert(
            ApiClientsCompanion.insert(
              id: 'client_${identifier.hashCode.abs()}',
              identifier: identifier,
              role: role,
              apiKeyHash: apiKeyHash,
              referrerOrigin: Value(referrerOrigin),
              createdAtMs: nowMs,
              updatedAtMs: nowMs,
            ),
          );
    }

    return AdoptionConfirmResult(
      apiKey: apiKey,
      identifier: identifier,
      role: role,
      permissions: permissionsForRole(role),
    );
  }

  Future<ApiClientRecord?> clientForApiKey(String apiKey) async {
    final hash = hashAdoptionApiKey(apiKey);
    final rows = await _db.select(_db.apiClients).get();
    for (final row in rows) {
      if (constantTimeStringEquals(row.apiKeyHash, hash)) {
        return ApiClientRecord(
          id: row.id,
          identifier: row.identifier,
          role: row.role,
          apiKeyHash: row.apiKeyHash,
          createdAtMs: row.createdAtMs,
          updatedAtMs: row.updatedAtMs,
        );
      }
    }
    return null;
  }

  Future<List<ApiClientListItem>> listClients() async {
    final rows = await _db.select(_db.apiClients).get();
    rows.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return [
      for (final row in rows)
        ApiClientListItem(
          id: row.id,
          identifier: row.identifier,
          role: row.role,
          maskedApiKey: maskAdoptionApiKeyHash(row.apiKeyHash),
          createdAtMs: row.createdAtMs,
          updatedAtMs: row.updatedAtMs,
        ),
    ];
  }

  Future<bool> revokeClient(String id) async {
    final deleted = await (_db.delete(_db.apiClients)..where((t) => t.id.equals(id)))
        .go();
    return deleted > 0;
  }

  Future<void> sweepExpiredPending({
    required int nowMs,
    Future<void> Function(int alertId)? dismissAlert,
  }) async {
    final expired = await (_db.select(_db.adoptionPending)
          ..where((t) => t.expiresAtMs.isSmallerOrEqualValue(nowMs)))
        .get();
    for (final row in expired) {
      await _deletePending(row, dismissAlert: dismissAlert);
    }
  }

  Future<void> _cancelPendingForIdentifier(
    String identifier, {
    required int nowMs,
    Future<void> Function(int alertId)? dismissAlert,
  }) async {
    final rows = await (_db.select(_db.adoptionPending)
          ..where((t) => t.identifier.equals(identifier)))
        .get();
    for (final row in rows) {
      await _deletePending(row, dismissAlert: dismissAlert);
    }
  }

  Future<void> _deletePending(
    AdoptionPendingData row, {
    Future<void> Function(int alertId)? dismissAlert,
  }) async {
    final alertId = row.alertId;
    if (alertId != null && dismissAlert != null) {
      await dismissAlert(alertId);
    }
    await (_db.delete(_db.adoptionPending)..where((t) => t.id.equals(row.id)))
        .go();
  }
}
