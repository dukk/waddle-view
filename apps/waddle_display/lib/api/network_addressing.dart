import 'dart:io';

import '../config/display_env.dart';
import 'http_tls.dart';

class HttpBindConfig {
  const HttpBindConfig({
    required this.address,
    required this.displayHost,
    required this.port,
    required this.tls,
  });

  final InternetAddress address;
  final String displayHost;
  final int port;
  final HttpTlsConfig tls;
}

Future<HttpBindConfig> resolveHttpBindConfig({
  Map<String, String>? environment,
  String? tlsCertDir,
}) async {
  final env = environment ?? Platform.environment;
  final bindHost = (env[kDisplayHttpBindIpEnv] ?? '').trim();
  final bindPortRaw = (env[kDisplayHttpPortEnv] ?? '').trim();
  final bindPort = int.tryParse(bindPortRaw);
  final port = bindPort != null && bindPort > 0 ? bindPort : 8787;

  final address = await _resolveBindAddress(bindHost);
  final displayHost = await _resolveDisplayHost(address);
  final tls = await resolveHttpTlsConfig(
    defaultCertDir: tlsCertDir ?? '',
    environment: env,
  );
  return HttpBindConfig(
    address: address,
    displayHost: displayHost,
    port: port,
    tls: tls,
  );
}

Future<InternetAddress> _resolveBindAddress(String bindHost) async {
  final host = bindHost.isEmpty ? '0.0.0.0' : bindHost;
  if (host == '0.0.0.0') {
    return InternetAddress.anyIPv4;
  }
  if (host == '::') {
    return InternetAddress.anyIPv6;
  }
  try {
    return InternetAddress(host);
  } catch (_) {
    return InternetAddress.anyIPv4;
  }
}

Future<String> _resolveDisplayHost(InternetAddress boundAddress) async {
  if (!boundAddress.isLoopback &&
      boundAddress.address != InternetAddress.anyIPv4.address &&
      boundAddress.address != InternetAddress.anyIPv6.address) {
    return boundAddress.address;
  }
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  for (final nic in interfaces) {
    for (final addr in nic.addresses) {
      if (!addr.isLoopback) {
        return addr.address;
      }
    }
  }
  return InternetAddress.loopbackIPv4.address;
}

/// Comma-separated origins for `Access-Control-Allow-Origin` (e.g. `http://localhost:5173`).
List<String> parseCorsAllowedOrigins(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
