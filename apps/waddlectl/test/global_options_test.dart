import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:waddlectl/app_paths.dart';
import 'package:waddlectl/global_options.dart';

void main() {
  test('fromArgResults uses explicit database path', () {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_opts');
    final db = File(p.join(tmp.path, 'waddle_view.sqlite'));
    db.writeAsStringSync('');
    final o = GlobalCliOptions.fromArgResults(
      databasePath: db.path,
      supportDirPath: null,
      output: 'json',
    );
    expect(o.databaseFile.path, db.path);
    expect(o.outputJson, isTrue);
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  test('default Linux path matches application id folder', () {
    if (!Platform.isLinux) {
      return;
    }
    final f = defaultLinuxWaddleSqliteFile();
    expect(f.path, contains('com.waddleview.waddle_display'));
    expect(f.path, endsWith('waddle_view.sqlite'));
  });
}
