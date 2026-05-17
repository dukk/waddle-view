import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../persistence/database.dart';
import 'aes_gcm_secret_cipher.dart';
import 'platform/dek_protector.dart';
import 'secret_repository.dart';
import 'secret_store.dart';

/// SQLite-backed [SecretStore] with a platform-wrapped DEK.
class DbEncryptedSecretStore implements SecretStore {
  DbEncryptedSecretStore({
    required AppDatabase db,
    required DekProtector protector,
    SecretRepository? repository,
  })  : _repo = repository ?? SecretRepository(db),
        _protector = protector;

  final SecretRepository _repo;
  final DekProtector _protector;

  SecretKey? _dek;
  final _dekLock = _AsyncLock();

  @override
  Future<String?> read(String key) async {
    final wire = await _repo.readCiphertext(key);
    if (wire == null || wire.isEmpty) {
      return null;
    }
    final dek = await _ensureDek();
    final plain = await AesGcmSecretCipher.decrypt(dek, wire);
    final s = utf8.decode(plain);
    if (s.isEmpty) {
      return null;
    }
    return s;
  }

  @override
  Future<void> write(String key, String value) async {
    final dek = await _ensureDek();
    final wire = await AesGcmSecretCipher.encrypt(
      dek,
      Uint8List.fromList(utf8.encode(value)),
    );
    await _repo.upsertCiphertext(key, wire);
  }

  @override
  Future<void> delete(String key) async {
    await _repo.deleteCiphertext(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    final dek = await _ensureDek();
    final rows = await _repo.listAllCiphertextRows();
    final out = <String, String>{};
    for (final row in rows) {
      final plain = await AesGcmSecretCipher.decrypt(dek, row.ciphertext);
      final s = utf8.decode(plain);
      if (s.isNotEmpty) {
        out[row.secretKey] = s;
      }
    }
    return out;
  }

  Future<SecretKey> _ensureDek() async {
    return _dekLock.synchronized(() async {
      if (_dek != null) {
        return _dek!;
      }
      final wrapped = await _repo.readWrappedDek();
      if (wrapped == null || wrapped.isEmpty) {
        final rnd = Random.secure();
        final plainDek = List<int>.generate(
          AesGcmSecretCipher.dekLength,
          (_) => rnd.nextInt(256),
        );
        final wrappedBytes = await _protector.wrap(plainDek);
        await _repo.writeWrappedDek(Uint8List.fromList(wrappedBytes));
        _dek = await AesGcmSecretCipher.secretKeyFromBytes(plainDek);
        return _dek!;
      }
      final plainDek = await _protector.unwrap(wrapped);
      _dek = await AesGcmSecretCipher.secretKeyFromBytes(plainDek);
      return _dek!;
    });
  }
}

/// Simple async mutex for DEK initialization.
class _AsyncLock {
  Future<void>? _chain;

  Future<T> synchronized<T>(Future<T> Function() action) {
    final prev = _chain;
    final completer = Completer<void>();
    _chain = completer.future;
    return () async {
      if (prev != null) {
        await prev;
      }
      try {
        return await action();
      } finally {
        completer.complete();
      }
    }();
  }
}
