import 'dart:io';

import 'package:waddle_shared/secrets/secret_store.dart';

import 'secret_bundle_codec.dart';

Future<int> exportSecretsToFile(
  SecretStore secrets,
  String password,
  File destination,
) async {
  final map = await secrets.readAll();
  final bytes = await encodeSecretBundle(map, password);
  await destination.writeAsBytes(bytes);
  return map.length;
}

Future<Map<String, String>> decodeSecretBundleFile(
  File file,
  String password,
) async {
  final bytes = await file.readAsBytes();
  return decodeSecretBundle(bytes, password);
}

Future<void> mergeSecretsImport(
  SecretStore secrets,
  Map<String, String> entries,
) async {
  for (final e in entries.entries) {
    if (e.value.isNotEmpty) {
      await secrets.write(e.key, e.value);
    }
  }
}
