import 'package:test/test.dart';
import 'package:waddle_shared/auth/cors_origin_normalize.dart';

void main() {
  test('normalizeHttpOrigin from Origin header value', () {
    expect(
      normalizeHttpOrigin('http://192.168.1.10:5173'),
      'http://192.168.1.10:5173',
    );
  });

  test('normalizeHttpOrigin from Referer strips path', () {
    expect(
      normalizeHttpOrigin('http://localhost:5173/displays'),
      'http://localhost:5173',
    );
  });

  test('normalizeHttpOrigin adds default https port', () {
    expect(
      normalizeHttpOrigin('https://display.local'),
      'https://display.local:443',
    );
  });

  test('normalizeHttpOrigin rejects non-http schemes', () {
    expect(normalizeHttpOrigin('file:///tmp'), isNull);
  });
}
