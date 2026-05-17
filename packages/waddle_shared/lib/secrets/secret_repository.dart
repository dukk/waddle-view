import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../persistence/tables.dart';

/// Drift access for [IntegrationSecrets] and [SecretStoreMeta].
class SecretRepository {
  SecretRepository(this._db);

  final AppDatabase _db;

  Future<Uint8List?> readCiphertext(String secretKey) async {
    final row = await (_db.select(_db.integrationSecrets)
          ..where((t) => t.secretKey.equals(secretKey)))
        .getSingleOrNull();
    return row?.ciphertext;
  }

  Future<void> upsertCiphertext(String secretKey, Uint8List ciphertext) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.integrationSecrets).insertOnConflictUpdate(
          IntegrationSecretsCompanion.insert(
            secretKey: secretKey,
            ciphertext: ciphertext,
            updatedAtMs: nowMs,
          ),
        );
  }

  Future<void> deleteCiphertext(String secretKey) async {
    await (_db.delete(_db.integrationSecrets)
          ..where((t) => t.secretKey.equals(secretKey)))
        .go();
  }

  Future<List<IntegrationSecret>> listAllCiphertextRows() =>
      _db.select(_db.integrationSecrets).get();

  Future<Uint8List?> readWrappedDek() async {
    final row = await (_db.select(_db.secretStoreMeta)
          ..where((t) => t.id.equals(kSecretStoreDekMetaId)))
        .getSingleOrNull();
    return row?.wrappedDek;
  }

  Future<void> writeWrappedDek(Uint8List wrapped, {int algorithmVersion = 1}) async {
    await _db.into(_db.secretStoreMeta).insertOnConflictUpdate(
          SecretStoreMetaCompanion.insert(
            id: kSecretStoreDekMetaId,
            wrappedDek: wrapped,
            algorithmVersion: algorithmVersion,
          ),
        );
  }
}
