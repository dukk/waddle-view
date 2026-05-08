import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/sleeper.dart';

void main() {
  test('SystemSleeper yields', () async {
    await SystemSleeper().sleep(const Duration(milliseconds: 2));
  });
}
