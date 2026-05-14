import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/blob/blob_store.dart';

void main() {
  group('BlobRef', () {
    test('equality uses storageKey only', () {
      const a = BlobRef('k1');
      const b = BlobRef('k1');
      const c = BlobRef('k2');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a == Object(), isFalse);
    });
  });
}
