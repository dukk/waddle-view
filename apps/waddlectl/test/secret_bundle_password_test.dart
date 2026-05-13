import 'package:flutter_test/flutter_test.dart';
import 'package:waddlectl/secret_bundle_password.dart';

void main() {
  test('password from environment map', () async {
    final pw = await resolveSecretBundlePassword(
      passwordFile: null,
      passwordEnv: 'MYVAR',
      confirm: false,
      environmentForTest: {'MYVAR': 'from-env'},
    );
    expect(pw, 'from-env');
  });

  test('interactive confirm match via iterator', () async {
    final pw = await resolveSecretBundlePassword(
      passwordFile: null,
      passwordEnv: null,
      confirm: true,
      stdinHasTerminalForTest: false,
      interactivePasswordLinesForTest: ['abc', 'abc'].iterator,
    );
    expect(pw, 'abc');
  });

  test('interactive confirm mismatch', () async {
    await expectLater(
      resolveSecretBundlePassword(
        passwordFile: null,
        passwordEnv: null,
        confirm: true,
        stdinHasTerminalForTest: false,
        interactivePasswordLinesForTest: ['a', 'b'].iterator,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Passwords do not match.',
        ),
      ),
    );
  });

  test('interactive empty password', () async {
    await expectLater(
      resolveSecretBundlePassword(
        passwordFile: null,
        passwordEnv: null,
        confirm: false,
        stdinHasTerminalForTest: false,
        interactivePasswordLinesForTest: ['   '].iterator,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Password must not be empty.',
        ),
      ),
    );
  });

  test('no TTY and no test iterator throws', () async {
    await expectLater(
      resolveSecretBundlePassword(
        passwordFile: null,
        passwordEnv: null,
        confirm: false,
        stdinHasTerminalForTest: false,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no TTY'),
        ),
      ),
    );
  });

  test('iterative password with null stdin override', () async {
    final pw = await resolveSecretBundlePassword(
      passwordFile: null,
      passwordEnv: null,
      confirm: false,
      interactivePasswordLinesForTest: ['from-stdin-branch'].iterator,
    );
    expect(pw, 'from-stdin-branch');
  });

  test('confirm mode exhausts iterator', () async {
    await expectLater(
      resolveSecretBundlePassword(
        passwordFile: null,
        passwordEnv: null,
        confirm: true,
        stdinHasTerminalForTest: false,
        interactivePasswordLinesForTest: ['only-one'].iterator,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('exhausted'),
        ),
      ),
    );
  });

  test('missing env var throws', () async {
    await expectLater(
      resolveSecretBundlePassword(
        passwordFile: null,
        passwordEnv: 'MISSING_X',
        confirm: false,
        environmentForTest: {},
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('MISSING_X'),
        ),
      ),
    );
  });
}
