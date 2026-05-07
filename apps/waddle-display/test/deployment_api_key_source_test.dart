import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/api/deployment_api_key_source.dart';

void main() {
  test('file source trims line', () async {
    final f = File(
      '${Directory.systemTemp.path}/waddle_key_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    await f.writeAsString('  abc  \n');
    final src = FileDeploymentApiKeySource(f);
    expect(await src.load(), 'abc');
    await f.delete();
  });
}
