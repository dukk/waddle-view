import 'dart:convert';
import 'dart:io';

import 'package:waddle_shared/secrets/secret_store.dart';

/// Matches [flutter_secure_storage_linux] C++ plugin: one keyring item whose
/// password body is a JSON object of all keys, with attributes
/// `account=com.waddleview.waddle_display.secureStorage` and label
/// `com.waddleview.waddle_display/FlutterSecureStorage`.
///
/// Requires `secret-tool` from the `libsecret-tools` / `secret` package on PATH.
class LinuxSecretToolSecretStore implements SecretStore {
  LinuxSecretToolSecretStore({
    this.secretToolBinary = 'secret-tool',
  });

  final String secretToolBinary;

  static const String _label =
      'com.waddleview.waddle_display/FlutterSecureStorage';

  static const String _accountAttr = 'account';
  static const String _accountValue =
      'com.waddleview.waddle_display.secureStorage';

  Future<Map<String, dynamic>> _readRoot() async {
    final result = await Process.run(secretToolBinary, [
      'lookup',
      _accountAttr,
      _accountValue,
    ]);
    if (result.exitCode != 0) {
      return {};
    }
    final raw = (result.stdout as String).trim();
    if (raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', v));
      }
    } on Object {
      return {};
    }
    return {};
  }

  Future<void> _writeRoot(Map<String, dynamic> root) async {
    final payload = jsonEncode(root);
    final proc = await Process.start(secretToolBinary, [
      'store',
      '--label=$_label',
      _accountAttr,
      _accountValue,
    ]);
    proc.stdin.write(payload);
    await proc.stdin.close();
    final err = await proc.stderr.transform(utf8.decoder).join();
    final code = await proc.exitCode;
    if (code != 0) {
      throw StateError(
        'secret-tool store failed (exit $code): ${err.trim()}',
      );
    }
  }

  @override
  Future<String?> read(String key) async {
    final root = await _readRoot();
    final v = root[key];
    if (v == null) {
      return null;
    }
    if (v is String) {
      return v;
    }
    return jsonEncode(v);
  }

  @override
  Future<void> write(String key, String value) async {
    final root = await _readRoot();
    root[key] = value;
    await _writeRoot(root);
  }

  @override
  Future<void> delete(String key) async {
    final root = await _readRoot();
    root.remove(key);
    await _writeRoot(root);
  }
}

SecretStore createPlatformSecretStore() {
  if (!Platform.isLinux) {
    throw UnsupportedError(
      'Secret commands require Linux and secret-tool (libsecret).',
    );
  }
  return LinuxSecretToolSecretStore();
}
