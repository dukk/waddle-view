import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// CPU architecture label for `GET /v1/health` (`arm64`, `x64`, `unknown`, …).
String detectPlatformArch() {
  if (kIsWeb) {
    return 'unknown';
  }
  try {
    final label = Abi.current().toString().toLowerCase();
    if (label.contains('arm64') || label.contains('aarch64')) return 'arm64';
    if (label.contains('arm')) return 'arm';
    if (label.contains('x64') || label.contains('x86_64') || label.contains('amd64')) {
      return 'x64';
    }
    if (label.contains('ia32') || label.contains('x86')) return 'ia32';
    if (label.contains('riscv')) return 'riscv64';
    final parts = label.split(RegExp(r'\s+'));
    if (parts.length >= 2) return parts.last;
  } on Object {
    // fall through to uname
  }
  if (Platform.isLinux || Platform.isMacOS) {
    try {
      final r = Process.runSync('uname', ['-m']);
      final m = (r.stdout as String).trim().toLowerCase();
      if (m == 'aarch64' || m == 'arm64') return 'arm64';
      if (m == 'x86_64' || m == 'amd64') return 'x64';
      return m.isEmpty ? 'unknown' : m;
    } on Object {
      return 'unknown';
    }
  }
  if (Platform.isWindows) {
    final arch = Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ?? '';
    if (arch.contains('arm64')) return 'arm64';
    if (arch.contains('amd64') || arch == 'x86') return 'x64';
  }
  return 'unknown';
}

/// True when this host is Linux arm64 with the Pi upgrade helper installed.
bool isPiUpgradeCapable({String? upgradeScriptPath}) {
  if (kIsWeb || !Platform.isLinux) {
    return false;
  }
  if (detectPlatformArch() != 'arm64') {
    return false;
  }
  final path = upgradeScriptPath?.trim();
  if (path == null || path.isEmpty) {
    return false;
  }
  return File(path).existsSync();
}
