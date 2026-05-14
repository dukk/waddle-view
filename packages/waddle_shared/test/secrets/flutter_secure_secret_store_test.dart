import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:waddle_shared/secrets/flutter_secure_secret_store.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockFlutterSecureStorage mock;
  late FlutterSecureSecretStore store;

  setUp(() {
    mock = _MockFlutterSecureStorage();
    store = FlutterSecureSecretStore(storage: mock);
  });

  test('read delegates to storage', () async {
    when(() => mock.read(key: any(named: 'key'))).thenAnswer((_) async => 'secret');
    expect(await store.read('k'), 'secret');
    verify(() => mock.read(key: 'k')).called(1);
  });

  test('write delegates to storage', () async {
    when(
      () => mock.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((_) async {});
    await store.write('k', 'v');
    verify(() => mock.write(key: 'k', value: 'v')).called(1);
  });

  test('delete delegates to storage', () async {
    when(() => mock.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    await store.delete('k');
    verify(() => mock.delete(key: 'k')).called(1);
  });

  test('readAll drops empty string values', () async {
    when(() => mock.readAll()).thenAnswer(
      (_) async => <String, String>{
        'a': '1',
        'b': '',
        'c': '2',
      },
    );
    expect(await store.readAll(), {'a': '1', 'c': '2'});
  });
}
