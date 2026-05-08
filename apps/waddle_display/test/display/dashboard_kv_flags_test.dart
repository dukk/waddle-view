import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/dashboard_kv_flags.dart';

void main() {
  test('null and blank use default', () {
    expect(isTruthyDashboardKvFlag(null, defaultValue: true), isTrue);
    expect(isTruthyDashboardKvFlag(null, defaultValue: false), isFalse);
    expect(isTruthyDashboardKvFlag('', defaultValue: true), isTrue);
    expect(isTruthyDashboardKvFlag('  ', defaultValue: false), isFalse);
  });

  test('known truthy tokens', () {
    for (final v in ['1', 'true', 'TRUE', ' yes ', 'On']) {
      expect(
        isTruthyDashboardKvFlag(v, defaultValue: false),
        isTrue,
        reason: v,
      );
    }
  });

  test('known falsy tokens', () {
    for (final v in ['0', 'false', 'FALSE', 'no', 'Off']) {
      expect(
        isTruthyDashboardKvFlag(v, defaultValue: true),
        isFalse,
        reason: v,
      );
    }
  });

  test('unknown strings use default', () {
    expect(isTruthyDashboardKvFlag('maybe', defaultValue: true), isTrue);
    expect(isTruthyDashboardKvFlag('maybe', defaultValue: false), isFalse);
  });
}
