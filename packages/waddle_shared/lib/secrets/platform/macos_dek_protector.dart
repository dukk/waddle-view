import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../aes_gcm_secret_cipher.dart';
import 'dek_protector.dart';

const _kMacOsDekWrapKekKey = 'waddle:dek_wrap_kek_v1';

/// macOS: host KEK in Keychain via [FlutterSecureStorage]; wrapped DEK in SQLite.
class MacOsDekProtector implements DekProtector {
  MacOsDekProtector({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<SecretKey> _loadOrCreateKek() async {
    final existing = await _storage.read(key: _kMacOsDekWrapKekKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      if (bytes.length == AesGcmSecretCipher.dekLength) {
        return AesGcmSecretCipher.secretKeyFromBytes(bytes);
      }
    }
    final rnd = Random.secure();
    final kekBytes = List<int>.generate(
      AesGcmSecretCipher.dekLength,
      (_) => rnd.nextInt(256),
    );
    await _storage.write(
      key: _kMacOsDekWrapKekKey,
      value: base64Encode(kekBytes),
    );
    return AesGcmSecretCipher.secretKeyFromBytes(kekBytes);
  }

  @override
  Future<List<int>> wrap(List<int> plainDek) async {
    if (plainDek.length != AesGcmSecretCipher.dekLength) {
      throw ArgumentError('plainDek must be ${AesGcmSecretCipher.dekLength} bytes');
    }
    final kek = await _loadOrCreateKek();
    return AesGcmSecretCipher.encrypt(kek, Uint8List.fromList(plainDek));
  }

  @override
  Future<List<int>> unwrap(List<int> wrappedDek) async {
    final kek = await _loadOrCreateKek();
    final plain = await AesGcmSecretCipher.decrypt(
      kek,
      Uint8List.fromList(wrappedDek),
    );
    return plain;
  }
}
