import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Integration type for subscribe-by-URL iCalendar / ICS feeds.
const String kIcalCalendarProviderId = 'calendar_ical';

/// Last successful iCal calendar collect (poll gate).
const String kIcalCalendarLastCollectKvKey =
    'provider.calendar_ical.last_collect_ms';

/// Prefix for [CalendarEvents.source] rows produced by an ICS feed.
String icalCalendarEventSource(String feedId) => 'ical_feed:$feedId';

/// Stable [CalendarEvents.id] for an event under a feed.
String icalCalendarEventRowId(String feedId, String uid) {
  final bytes = utf8.encode('ical_feed\x00$feedId\x00$uid');
  return sha256.convert(bytes).toString();
}
