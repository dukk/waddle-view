import 'package:test/test.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

void main() {
  test('readAll returns all stored string entries', () async {
    final s = InMemorySecretStore();
    await s.write('a', '1');
    await s.write('b', '2');
    expect(await s.readAll(), {'a': '1', 'b': '2'});
  });

  test('readAll reflects deletes', () async {
    final s = InMemorySecretStore();
    await s.write('k', 'v');
    await s.delete('k');
    expect(await s.readAll(), isEmpty);
  });
}
