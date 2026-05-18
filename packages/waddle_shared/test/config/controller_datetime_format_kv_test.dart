import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';

void main() {
  group('normalizeControllerTimeFormat', () {
    test('defaults for null, empty, and unknown', () {
      expect(normalizeControllerTimeFormat(null), kDefaultControllerTimeFormat);
      expect(normalizeControllerTimeFormat(''), kDefaultControllerTimeFormat);
      expect(normalizeControllerTimeFormat('bogus'), kDefaultControllerTimeFormat);
    });

    test('accepts 24h variants', () {
      expect(normalizeControllerTimeFormat('24h'), kControllerTimeFormat24h);
      expect(normalizeControllerTimeFormat(' 24H '), kControllerTimeFormat24h);
      expect(normalizeControllerTimeFormat('24'), kControllerTimeFormat24h);
    });

    test('accepts 12h explicitly', () {
      expect(normalizeControllerTimeFormat('12h'), kControllerTimeFormat12h);
    });
  });

  group('normalizeControllerDateOrder', () {
    test('defaults for null, empty, and unknown', () {
      expect(normalizeControllerDateOrder(null), kDefaultControllerDateOrder);
      expect(normalizeControllerDateOrder(''), kDefaultControllerDateOrder);
      expect(normalizeControllerDateOrder('xyz'), kDefaultControllerDateOrder);
    });

    test('accepts dmy and ymd', () {
      expect(normalizeControllerDateOrder('dmy'), kControllerDateOrderDmy);
      expect(normalizeControllerDateOrder(' DMY '), kControllerDateOrderDmy);
      expect(normalizeControllerDateOrder('ymd'), kControllerDateOrderYmd);
    });

    test('accepts mdy', () {
      expect(normalizeControllerDateOrder('mdy'), kControllerDateOrderMdy);
    });
  });
}
