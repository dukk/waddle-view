import 'dek_protector.dart';

/// Test-only protector: stores DEK bytes without additional wrapping.
class InMemoryDekProtector implements DekProtector {
  InMemoryDekProtector();

  @override
  Future<List<int>> wrap(List<int> plainDek) async => List<int>.from(plainDek);

  @override
  Future<List<int>> unwrap(List<int> wrappedDek) async =>
      List<int>.from(wrappedDek);
}
