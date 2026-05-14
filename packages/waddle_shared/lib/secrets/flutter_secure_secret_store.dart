import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secret_store.dart';

/// Linux: libsecret / Secret Service when available.
class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() async {
    final raw = await _storage.readAll();
    final out = <String, String>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v.isNotEmpty) {
        out[e.key] = v;
      }
    }
    return out;
  }
}
