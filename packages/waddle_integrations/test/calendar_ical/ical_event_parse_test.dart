import 'package:test/test.dart';
import 'package:waddle_data_providers/calendar_ical/ical_event_parse.dart';

void main() {
  group('parseIcalFeedEvents', () {
    test('parses timed and all-day VEVENT rows', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Waddle//Test//EN
BEGIN:VEVENT
UID:evt-timed
SUMMARY:Standup
DTSTART:20260601T100000Z
DTEND:20260601T110000Z
LOCATION:Room A
END:VEVENT
BEGIN:VEVENT
UID:evt-allday
SUMMARY:Holiday
DTSTART;VALUE=DATE:20260615
DTEND;VALUE=DATE:20260616
END:VEVENT
BEGIN:VEVENT
UID:cancelled
SUMMARY:Gone
STATUS:CANCELLED
DTSTART:20260602T120000Z
DTEND:20260602T130000Z
END:VEVENT
END:VCALENDAR
''';
      final events = parseIcalFeedEvents(ics);
      expect(events.map((e) => e.uid).toList(), ['evt-timed', 'evt-allday']);
      expect(events[0].uid, 'evt-timed');
      expect(events[0].title, 'Standup');
      expect(events[0].allDay, isFalse);
      expect(events[0].location, 'Room A');
      expect(events[0].startUtc, DateTime.utc(2026, 6, 1, 10));
      expect(events[0].endUtc, DateTime.utc(2026, 6, 1, 11));
      expect(events[1].uid, 'evt-allday');
      expect(events[1].allDay, isTrue);
      expect(events[1].startUtc, DateTime.utc(2026, 6, 15));
    });
  });
}
