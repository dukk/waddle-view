import 'dart:convert';
import 'dart:io';

/// Resolves a bundle password with precedence: [passwordFile] over [passwordEnv]
/// over interactive [stdin]. When [confirm] is true (export), reads and checks
/// two matching passwords.
///
/// [environmentForTest], [stdinHasTerminalForTest], and
/// [interactivePasswordLinesForTest] are for unit tests only (non-null disables
/// real stdin for the interactive path).
///
/// Throws [StateError] with an operator-facing message for invalid non-interactive
/// inputs; callers should turn these into [UsageException] where appropriate.
Future<String> resolveSecretBundlePassword({
  required String? passwordFile,
  required String? passwordEnv,
  required bool confirm,
  Map<String, String>? environmentForTest,
  bool? stdinHasTerminalForTest,
  Iterator<String>? interactivePasswordLinesForTest,
}) async {
  final env = environmentForTest ?? Platform.environment;
  final fromFile = await _tryPasswordFile(passwordFile);
  if (fromFile != null) {
    return fromFile;
  }

  final fromEnv = _tryPasswordEnv(passwordEnv, env);
  if (fromEnv != null) {
    return fromEnv;
  }

  final testIt = interactivePasswordLinesForTest;
  final hasTerminal = stdinHasTerminalForTest ?? stdin.hasTerminal;
  if (testIt == null && !hasTerminal) {
    throw StateError(
      'Cannot prompt for password (no TTY). '
      'Use --password-file=PATH or --password-env=NAME.',
    );
  }

  stdout.writeln('Enter bundle password:');
  final first = _readNextLine(testIt);
  stdout.writeln();
  if (first.isEmpty) {
    throw StateError('Password must not be empty.');
  }
  if (confirm) {
    stdout.writeln('Confirm bundle password:');
    final second = _readNextLine(testIt);
    stdout.writeln();
    if (first != second) {
      throw StateError('Passwords do not match.');
    }
  }
  return first;
}

Future<String?> _tryPasswordFile(String? path) async {
  if (path == null || path.isEmpty) {
    return null;
  }
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('Password file not found: $path');
  }
  final raw = await file.readAsString();
  final lines = const LineSplitter().convert(raw);
  final line = lines.isEmpty ? '' : lines.first.trim();
  if (line.isEmpty) {
    throw StateError('Password file is empty: $path');
  }
  return line;
}

String? _tryPasswordEnv(String? name, Map<String, String> env) {
  if (name == null || name.isEmpty) {
    return null;
  }
  final v = env[name];
  if (v == null || v.isEmpty) {
    throw StateError(
      'Environment variable ${jsonEncode(name)} is unset or empty.',
    );
  }
  return v;
}

String _readNextLine(Iterator<String>? testIt) {
  if (testIt != null) {
    if (!testIt.moveNext()) {
      throw StateError('Password prompt iterator exhausted.');
    }
    return testIt.current.trim();
  }
  return _readHiddenPasswordLine();
}

String _readHiddenPasswordLine() {
  final wasEcho = stdin.echoMode;
  try {
    stdin.echoMode = false;
    final line = stdin.readLineSync(encoding: utf8);
    return line?.trim() ?? '';
  } finally {
    stdin.echoMode = wasEcho;
  }
}
