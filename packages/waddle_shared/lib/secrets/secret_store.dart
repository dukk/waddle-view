/// OS-backed or in-memory secret storage. Never log returned values.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// All keys currently stored with non-empty string values (same
  /// stringification rules as [read] where applicable).
  Future<Map<String, String>> readAll();
}
