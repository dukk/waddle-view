import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/alerts/alert_material_icon.dart';
import 'package:waddle_view/alerts/alert_severity_icons_kv.dart';

void main() {
  test('parse merges JSON over defaults', () {
    final m = parseAlertSeverityIconsKv(
      '{"warning":"favorite","custom":"egg_alt"}',
    );
    expect(m['info'], 'info_outline');
    expect(m['auth'], 'lock_outline');
    expect(m['warning'], 'favorite');
    expect(m['error'], 'error_outline');
    expect(m['custom'], 'egg_alt');
  });

  test('parse ignores invalid JSON', () {
    final m = parseAlertSeverityIconsKv('not-json');
    expect(m['warning'], 'warning_amber_rounded');
  });

  test('resolveAlertSeverityIcon uses override and defaults', () {
    final cfg = parseAlertSeverityIconsKv('{"info":"egg_alt"}');
    expect(resolveAlertSeverityIcon('info', cfg), Icons.egg_outlined);
    expect(resolveAlertSeverityIcon('warning', cfg), Icons.warning_amber_rounded);
    expect(resolveAlertSeverityIcon('auth', cfg), Icons.lock_outline);
  });
}
