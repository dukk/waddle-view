import 'package:icalendar_parser/icalendar_parser.dart';

import '../shared/provider_calendar_date_time.dart';

/// One [VEVENT] from an ICS feed, ready for persistence.
class ParsedIcalEvent {
  const ParsedIcalEvent({
    required this.uid,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    required this.allDay,
    this.location,
    this.description,
  });

  final String uid;
  final String title;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool allDay;
  final String? location;
  final String? description;
}

/// Parses ICS text into [VEVENT] rows (non-cancelled, with UID and start).
List<ParsedIcalEvent> parseIcalFeedEvents(String icsBody) {
  final cal = ICalendar.fromString(icsBody);
  final out = <ParsedIcalEvent>[];
  for (final component in cal.data) {
    final type = component['type'];
    if (type is! String || type.toUpperCase() != 'VEVENT') {
      continue;
    }
    final status = component['status'];
    if (status is IcsStatus && status == IcsStatus.cancelled) {
      continue;
    }
    if (status is String && status.toUpperCase() == 'CANCELLED') {
      continue;
    }
    final uidRaw = component['uid'];
    if (uidRaw is! String || uidRaw.trim().isEmpty) {
      continue;
    }
    final uid = uidRaw.trim();
    final dtstart = component['dtstart'];
    final dtend = component['dtend'];
    if (dtstart is! IcsDateTime) {
      continue;
    }
    final allDay = _isAllDay(dtstart, dtend);
    final startUtc = parseIcsDateTimeUtc(dtstart, isAllDay: allDay);
    if (startUtc == null) {
      continue;
    }
    DateTime? endUtc;
    if (dtend is IcsDateTime) {
      endUtc = parseIcsDateTimeUtc(dtend, isAllDay: allDay);
    }
    endUtc ??= allDay
        ? startUtc.add(const Duration(days: 1))
        : startUtc.add(const Duration(hours: 1));
    if (!endUtc.isAfter(startUtc)) {
      endUtc = allDay
          ? startUtc.add(const Duration(days: 1))
          : startUtc.add(const Duration(hours: 1));
    }
    final summary = component['summary'];
    final title = summary is String && summary.trim().isNotEmpty
        ? summary.trim()
        : '(no title)';
    final locationRaw = component['location'];
    final descriptionRaw = component['description'];
    out.add(
      ParsedIcalEvent(
        uid: uid,
        title: title,
        startUtc: startUtc,
        endUtc: endUtc,
        allDay: allDay,
        location: locationRaw is String && locationRaw.isNotEmpty
            ? locationRaw
            : null,
        description: descriptionRaw is String && descriptionRaw.isNotEmpty
            ? descriptionRaw
            : null,
      ),
    );
  }
  return out;
}

bool _isAllDay(IcsDateTime start, Object? dtend) {
  if (_icsDtIsDateOnly(start.dt)) {
    return true;
  }
  if (dtend is IcsDateTime && _icsDtIsDateOnly(dtend.dt)) {
    return true;
  }
  return false;
}

bool _icsDtIsDateOnly(String dt) {
  final t = dt.trim();
  return RegExp(r'^\d{8}$').hasMatch(t);
}

/// Interprets [IcsDateTime] as a UTC instant for [CalendarEvents] storage.
DateTime? parseIcsDateTimeUtc(IcsDateTime raw, {required bool isAllDay}) {
  final dt = raw.dt.trim();
  if (dt.isEmpty) {
    return null;
  }
  if (isAllDay || _icsDtIsDateOnly(dt)) {
    final ymd = _icsDateOnlyToYmd(dt);
    if (ymd == null) {
      return null;
    }
    return parseCalendarApiAllDayStartUtc(
      date: ymd,
      optionalTimeZoneName: raw.tzid,
    );
  }
  final iso = _icsDateTimeToIso8601(dt);
  if (iso == null) {
    return null;
  }
  if (dt.endsWith('Z') || dt.endsWith('z')) {
    final parsed = DateTime.tryParse(iso);
    return parsed?.toUtc();
  }
  return parseCalendarApiDateTimeUtc(
    dateTimeIso: iso,
    optionalTimeZoneName: raw.tzid,
  );
}

String? _icsDateOnlyToYmd(String dt) {
  if (!_icsDtIsDateOnly(dt)) {
    return null;
  }
  return '${dt.substring(0, 4)}-${dt.substring(4, 6)}-${dt.substring(6, 8)}';
}

String? _icsDateTimeToIso8601(String dt) {
  final t = dt.trim();
  if (_icsDtIsDateOnly(t)) {
    return '${_icsDateOnlyToYmd(t)}T00:00:00';
  }
  final m = RegExp(r'^(\d{8})T(\d{6})(Z)?$', caseSensitive: false).firstMatch(t);
  if (m == null) {
    return DateTime.tryParse(t)?.toUtc().toIso8601String();
  }
  final date = m.group(1)!;
  final time = m.group(2)!;
  final z = m.group(3);
  final iso =
      '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}'
      'T${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}';
  return z != null ? '${iso}Z' : iso;
}
