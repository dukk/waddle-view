import 'dart:io';

import 'package:path/path.dart' as p;

/// GTK application id from [waddle_display/linux/CMakeLists.txt].
const String kWaddleLinuxApplicationId = 'com.waddleview.waddle_display';

/// Default SQLite path when [Platform.isLinux] (matches Flutter `path_provider` support dir).
File defaultLinuxWaddleSqliteFile() {
  final home = Platform.environment['HOME'] ?? '';
  final xdgData =
      Platform.environment['XDG_DATA_HOME']?.trim().isNotEmpty == true
      ? Platform.environment['XDG_DATA_HOME']!.trim()
      : (home.isEmpty
            ? p.join('.local', 'share')
            : p.join(home, '.local', 'share'));
  return File(p.join(xdgData, kWaddleLinuxApplicationId, 'waddle_display.db'));
}
