import 'dart:io';

import 'package:flutter/foundation.dart';

/// Resolves the X11 window id for capture (GTK title [kLinuxWindowTitle]).
///
/// Order: [kDisplayWindowXidEnv], then `xdotool search --name <title>`.
Future<int?> resolveLinuxCaptureWindowXid() async {
  if (kIsWeb || !Platform.isLinux) return null;

  final fromEnv = Platform.environment[kDisplayWindowXidEnv]?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return int.tryParse(fromEnv);
  }

  try {
    final result = await Process.run(
      'xdotool',
      ['search', '--name', kLinuxWindowTitle],
      runInShell: false,
    );
    if (result.exitCode != 0) return null;
    final lines = '${result.stdout}'.trim().split(RegExp(r'\s+'));
    for (final line in lines.reversed) {
      final id = int.tryParse(line.trim());
      if (id != null && id > 0) return id;
    }
  } on ProcessException {
    return null;
  } on IOException {
    return null;
  }
  return null;
}

/// GTK window title set in [my_application.cc].
const String kLinuxWindowTitle = 'waddle_display';

/// Override X11 window id for live preview capture (hex or decimal).
const String kDisplayWindowXidEnv = 'WADDLE_DISPLAY_WINDOW_XID';
