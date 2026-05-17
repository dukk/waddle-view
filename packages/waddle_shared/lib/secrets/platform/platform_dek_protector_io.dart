import 'dart:io';

import 'dek_protector.dart';
import 'in_memory_dek_protector.dart';
import 'linux_dek_protector.dart';
import 'macos_dek_protector.dart';
import 'windows_dek_protector.dart';

DekProtector createPlatformDekProtector() {
  if (Platform.isWindows) {
    return WindowsDekProtector();
  }
  if (Platform.isLinux) {
    return LinuxDekProtector();
  }
  if (Platform.isMacOS) {
    return MacOsDekProtector();
  }
  return InMemoryDekProtector();
}
