/// Platform-specific wrap/unwrap for the SQLite secret-store DEK.
abstract class DekProtector {
  Future<List<int>> wrap(List<int> plainDek);

  Future<List<int>> unwrap(List<int> wrappedDek);
}
