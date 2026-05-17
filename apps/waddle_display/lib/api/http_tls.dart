import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/display_env.dart';
import 'bundled_dev_tls.dart';

/// TLS settings for the embedded display REST server.
class HttpTlsConfig {
  const HttpTlsConfig({
    required this.enabled,
    this.certPath,
    this.keyPath,
  });

  final bool enabled;
  final String? certPath;
  final String? keyPath;
}

bool _envTlsEnabled(Map<String, String> env) {
  final raw = (env[kDisplayHttpTlsEnv] ?? '').trim();
  if (raw.isEmpty) return true;
  final lower = raw.toLowerCase();
  if (raw == '0' || lower == 'false' || lower == 'no') return false;
  return raw == '1' || lower == 'true' || lower == 'yes';
}

/// Resolves TLS env and ensures a self-signed cert exists when enabled.
Future<HttpTlsConfig> resolveHttpTlsConfig({
  required String defaultCertDir,
  Map<String, String>? environment,
}) async {
  final env = environment ?? Platform.environment;
  if (!_envTlsEnabled(env)) {
    return const HttpTlsConfig(enabled: false);
  }

  final certOverride = (env[kDisplayHttpTlsCertEnv] ?? '').trim();
  final keyOverride = (env[kDisplayHttpTlsKeyEnv] ?? '').trim();
  if (certOverride.isNotEmpty && keyOverride.isNotEmpty) {
    return HttpTlsConfig(
      enabled: true,
      certPath: certOverride,
      keyPath: keyOverride,
    );
  }

  final dir = (env[kDisplayHttpTlsDirEnv] ?? '').trim().isNotEmpty
      ? env[kDisplayHttpTlsDirEnv]!.trim()
      : defaultCertDir;
  if (dir.isEmpty) {
    throw ArgumentError(
      'TLS is enabled but no cert directory was provided '
      '(set $kDisplayHttpTlsDirEnv or pass tlsCertDir to resolveHttpBindConfig)',
    );
  }
  final paths = await ensureSelfSignedCert(
    dir: dir,
    commonName: 'waddle-display',
  );
  return HttpTlsConfig(
    enabled: true,
    certPath: paths.certPath,
    keyPath: paths.keyPath,
  );
}

typedef SelfSignedCertPaths = ({String certPath, String keyPath});

/// Creates or reuses `cert.pem` / `key.pem` under [dir] via OpenSSL.
Future<SelfSignedCertPaths> ensureSelfSignedCert({
  required String dir,
  required String commonName,
}) async {
  await Directory(dir).create(recursive: true);
  final keyPath = p.join(dir, 'key.pem');
  final certPath = p.join(dir, 'cert.pem');
  final keyFile = File(keyPath);
  final certFile = File(certPath);
  if (await keyFile.exists() && await certFile.exists()) {
    return (certPath: certPath, keyPath: keyPath);
  }

  try {
    final result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      keyPath,
      '-out',
      certPath,
      '-days',
      '825',
      '-subj',
      '/CN=$commonName',
    ]);
    if (result.exitCode == 0) {
      return (certPath: certPath, keyPath: keyPath);
    }
  } on ProcessException {
    // OpenSSL missing (common on Windows) — fall back to bundled dev cert.
  }
  await keyFile.writeAsString(bundledDevTlsPrivateKeyPem);
  await certFile.writeAsString(bundledDevTlsCertificatePem);
  return (certPath: certPath, keyPath: keyPath);
}

SecurityContext securityContextFromPaths({
  required String certPath,
  required String keyPath,
}) {
  final ctx = SecurityContext();
  ctx.useCertificateChain(certPath);
  ctx.usePrivateKey(keyPath);
  return ctx;
}

String httpSchemeForTls(bool tlsEnabled) => tlsEnabled ? 'https' : 'http';
