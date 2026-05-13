import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddlectl/secret_bundle_ops.dart';
import 'package:waddlectl/secret_bundle_password.dart';

void main() {
  test('export then merge import preserves and adds keys', () async {
    final tmp = Directory.systemTemp.createTempSync('bundle_ops');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final s1 = InMemorySecretStore();
    await s1.write('a', '1');
    await s1.write('b', '2');

    final out = File(p.join(tmp.path, 'bundle.bin'));
    final n = await exportSecretsToFile(s1, 'secret', out);
    expect(n, 2);

    final s2 = InMemorySecretStore();
    await s2.write('c', '3');
    final decoded = await decodeSecretBundleFile(out, 'secret');
    await mergeSecretsImport(s2, decoded);

    expect(await s2.readAll(), {'a': '1', 'b': '2', 'c': '3'});
  });

  test('resolveSecretBundlePassword reads password file', () async {
    final tmp = Directory.systemTemp.createTempSync('pwfile');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final f = File(p.join(tmp.path, 'pw.txt'));
    await f.writeAsString('from-file\n');

    final pw = await resolveSecretBundlePassword(
      passwordFile: f.path,
      passwordEnv: null,
      confirm: false,
    );
    expect(pw, 'from-file');
  });

  test('empty password file throws StateError', () async {
    final tmp = Directory.systemTemp.createTempSync('pwempty');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final f = File(p.join(tmp.path, 'pw.txt'));
    await f.writeAsString('\n');

    await expectLater(
      resolveSecretBundlePassword(
        passwordFile: f.path,
        passwordEnv: null,
        confirm: false,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('missing password file throws StateError', () async {
    await expectLater(
      resolveSecretBundlePassword(
        passwordFile: '/nonexistent/waddle_pw.txt',
        passwordEnv: null,
        confirm: false,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        ),
      ),
    );
  });
}
