import 'package:test/test.dart';
import 'package:waddle_data_providers/calendar_ical/ical_feed_url.dart';

void main() {
  test('normalizeIcalFeedUri accepts https and maps webcal', () {
    expect(
      normalizeIcalFeedUri('https://example.com/cal.ics')?.toString(),
      'https://example.com/cal.ics',
    );
    expect(
      normalizeIcalFeedUri('webcal://example.com/cal.ics')?.toString(),
      'https://example.com/cal.ics',
    );
    expect(normalizeIcalFeedUri('ftp://example.com/x.ics'), isNull);
    expect(normalizeIcalFeedUri(''), isNull);
  });
}
