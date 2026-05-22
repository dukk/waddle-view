import 'package:waddle_shared/config/display_remote_view.dart';

import 'display_env.dart';

/// Applies [WADDLE_DISPLAY_REMOTE_VIEW_*] env vars as defaults when KV is unset.
void applyDisplayRemoteViewEnvDefaults(Map<String, String> env) {
  final enabledRaw = (env[kDisplayRemoteViewEnabledEnv] ?? '').trim();
  if (enabledRaw.isNotEmpty) {
    DisplayRemoteViewEnvDefaults.enabled = parseDisplayRemoteViewEnabled(enabledRaw);
  }
  final host = (env[kDisplayRemoteViewHostEnv] ?? '').trim();
  if (host.isNotEmpty) {
    DisplayRemoteViewEnvDefaults.host = host;
  }
  final portRaw = (env[kDisplayRemoteViewPortEnv] ?? '').trim();
  if (portRaw.isNotEmpty) {
    DisplayRemoteViewEnvDefaults.port = normalizeDisplayRemoteViewPort(portRaw);
  }
  final path = (env[kDisplayRemoteViewPathEnv] ?? '').trim();
  if (path.isNotEmpty) {
    DisplayRemoteViewEnvDefaults.path = normalizeDisplayRemoteViewPath(path);
  }
}
