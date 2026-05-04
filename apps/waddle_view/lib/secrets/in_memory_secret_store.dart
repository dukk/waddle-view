import 'secret_store.dart';

class InMemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  Map<String, String> get debugSnapshot =>
      Map<String, String>.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
