/// Operator remote desktop (VNC via websockify) settings in [config_key_values].
library;

import 'package:meta/meta.dart';

const String kDisplayRemoteViewEnabledKvKey = 'display.remote_view.enabled';
const String kDisplayRemoteViewHostKvKey = 'display.remote_view.host';
const String kDisplayRemoteViewPortKvKey = 'display.remote_view.port';
const String kDisplayRemoteViewPathKvKey = 'display.remote_view.path';

/// [SecretStore] key for optional VNC password (never stored in KV).
const String kDisplayRemoteViewVncPasswordSecretKey =
    'display.remote_view.vnc_password';

const String kDefaultDisplayRemoteViewHost = '127.0.0.1';
const int kDefaultDisplayRemoteViewPort = 6080;
const String kDefaultDisplayRemoteViewPath = '/';

/// Optional env fallbacks when KV is unset (see [DisplayRemoteViewEnvDefaults]).
abstract final class DisplayRemoteViewEnvDefaults {
  const DisplayRemoteViewEnvDefaults._();

  static bool? enabled;
  static String? host;
  static int? port;
  static String? path;
}

/// Parsed remote-view settings from KV plus optional env defaults.
@immutable
class DisplayRemoteViewConfig {
  const DisplayRemoteViewConfig({
    required this.enabled,
    required this.host,
    required this.port,
    required this.path,
  });

  final bool enabled;
  final String host;
  final int port;
  final String path;

  /// True when enabled and host/port are usable for a relay session.
  bool get configured => enabled && host.isNotEmpty && port > 0 && port <= 65535;

  /// Normalized WebSocket path (leading slash, no trailing slash except root).
  String get normalizedPath {
    var p = path.trim();
    if (p.isEmpty) return '/';
    if (!p.startsWith('/')) p = '/$p';
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// Upstream websockify URL for relay (ws scheme).
  Uri get upstreamWebsocketUri => Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: normalizedPath == '/' ? '' : normalizedPath,
      );
}

/// Whether [raw] KV/env value means remote view is enabled.
bool parseDisplayRemoteViewEnabled(Object? raw) {
  if (raw == null) return false;
  if (raw is bool) return raw;
  final s = '$raw'.trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'on';
}

String normalizeDisplayRemoteViewHost(Object? raw) {
  final s = raw == null ? '' : '$raw'.trim();
  if (s.isEmpty) return kDefaultDisplayRemoteViewHost;
  return s;
}

int normalizeDisplayRemoteViewPort(Object? raw) {
  if (raw is int) {
    return raw.clamp(1, 65535);
  }
  final parsed = int.tryParse('${raw ?? ''}'.trim());
  if (parsed == null || parsed < 1 || parsed > 65535) {
    return kDefaultDisplayRemoteViewPort;
  }
  return parsed;
}

String normalizeDisplayRemoteViewPath(Object? raw) {
  var p = raw == null ? '' : '$raw'.trim();
  if (p.isEmpty) return kDefaultDisplayRemoteViewPath;
  if (!p.startsWith('/')) p = '/$p';
  if (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

/// Reads remote-view config from a KV map with optional [DisplayRemoteViewEnvDefaults].
DisplayRemoteViewConfig displayRemoteViewConfigFromKv(Map<String, String> kv) {
  final enabledRaw = kv[kDisplayRemoteViewEnabledKvKey] ??
      DisplayRemoteViewEnvDefaults.enabled?.toString();
  final enabled = parseDisplayRemoteViewEnabled(enabledRaw);
  final host = normalizeDisplayRemoteViewHost(
    kv[kDisplayRemoteViewHostKvKey] ?? DisplayRemoteViewEnvDefaults.host,
  );
  final port = normalizeDisplayRemoteViewPort(
    kv[kDisplayRemoteViewPortKvKey] ??
        DisplayRemoteViewEnvDefaults.port?.toString(),
  );
  final path = normalizeDisplayRemoteViewPath(
    kv[kDisplayRemoteViewPathKvKey] ?? DisplayRemoteViewEnvDefaults.path,
  );
  return DisplayRemoteViewConfig(
    enabled: enabled,
    host: host,
    port: port,
    path: path,
  );
}

/// JSON fields for operator settings GET (password flag supplied separately).
Map<String, dynamic> displayRemoteViewSettingsJson(DisplayRemoteViewConfig config) {
  return {
    'display_remote_view_enabled': config.enabled,
    'display_remote_view_host': config.host,
    'display_remote_view_port': config.port,
    'display_remote_view_path': config.path,
  };
}
