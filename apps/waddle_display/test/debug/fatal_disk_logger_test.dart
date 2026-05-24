import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_display/debug/fatal_disk_logger.dart';

void main() {
  tearDown(() async {
    FatalDiskLogger.setSupportDirectoryOverrideForTest(null);
    await FatalDiskLogger.closeForTest();
  });

  test('appendFatal writes under fatal_logs/', () async {
    final tmp = await Directory.systemTemp.createTemp('fatal_log_test_');
    addTearDown(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });
    FatalDiskLogger.setSupportDirectoryOverrideForTest(() async => tmp);
    await FatalDiskLogger.appendFatal(
      'Flutter',
      StateError('decode failed'),
      StackTrace.fromString('#0 fake'),
    );
    await FatalDiskLogger.closeForTest();

    final logsDir = Directory(p.join(tmp.path, 'fatal_logs'));
    expect(logsDir.existsSync(), isTrue);
    final file = logsDir.listSync().whereType<File>().single;
    final text = await file.readAsString();
    expect(text, contains('[Fatal.Flutter]'));
    expect(text, contains("Instance of 'StateError'"));
    expect(text, contains('#0 fake'));
  });
}
