import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/display_instance_id_source.dart';

void main() {
  test('loads trimmed instance id from file', () async {
    final dir = await Directory.systemTemp.createTemp('wv_inst_');
    final file = File('${dir.path}/waddle_instance.id');
    await file.writeAsString('  abc123  \n');
    final src = FileDisplayInstanceIdSource(file);
    expect(await src.load(), 'abc123');
  });

  test('missing file returns null', () async {
    final dir = await Directory.systemTemp.createTemp('wv_inst_');
    final file = File('${dir.path}/missing.id');
    final src = FileDisplayInstanceIdSource(file);
    expect(await src.load(), isNull);
  });
}
