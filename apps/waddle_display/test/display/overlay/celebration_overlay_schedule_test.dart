import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/celebration_overlay_schedule.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:waddle_shared/persistence/tables.dart';

DisplayOverlayScheduleRow _rowNth({
  required int sm,
  int sd = 1,
  int? nthWeek,
  int? nthDay,
}) {
  return DisplayOverlayScheduleRow(
    id: 't',
    enabled: true,
    overlayKind: kOverlayKindHeartsRain,
    label: '',
    messagesJson: '[]',
    repeatAnnually: true,
    yearExact: null,
    startMonth: sm,
    startDay: sd,
    endMonth: null,
    endDay: null,
    nthWeekOfMonth: nthWeek,
    nthWeekday: nthDay,
  );
}

DisplayOverlayScheduleRow _rowFixed({
  required int sm,
  required int sd,
  int? em,
  int? ed,
  bool repeatAnnual = true,
  int? y,
}) {
  return DisplayOverlayScheduleRow(
    id: 'f',
    enabled: true,
    overlayKind: kOverlayKindHeartsRain,
    label: '',
    messagesJson: '[]',
    repeatAnnually: repeatAnnual,
    yearExact: y,
    startMonth: sm,
    startDay: sd,
    endMonth: em,
    endDay: ed,
    nthWeekOfMonth: null,
    nthWeekday: null,
  );
}

void main() {
  test('nth: 2nd Sunday in May (US Mothers Day)', () {
    expect(
      nthWeekdayOccurrenceInMonth(
        year: 2026,
        month: 5,
        nthWeekInMonth: 2,
        weekday: DateTime.sunday,
      ),
      DateTime(2026, 5, 10),
    );
    expect(
      nthWeekdayOccurrenceInMonth(
        year: 2025,
        month: 5,
        nthWeekInMonth: 2,
        weekday: DateTime.sunday,
      ),
      DateTime(2025, 5, 11),
    );
  });

  test('matches nth schedule on resolved day only', () {
    final r = _rowNth(sm: 5, nthWeek: 2, nthDay: DateTime.sunday);
    expect(matchesCelebrationOverlay(r, DateTime(2026, 5, 10)), isTrue);
    expect(matchesCelebrationOverlay(r, DateTime(2026, 5, 9)), isFalse);
  });

  test('matches fixed single-day annually', () {
    final r = _rowFixed(sm: 2, sd: 14);
    expect(matchesCelebrationOverlay(r, DateTime(2030, 2, 14)), isTrue);
    expect(matchesCelebrationOverlay(r, DateTime(2030, 2, 13)), isFalse);
  });

  test('matches inclusive fixed range within year', () {
    final r = _rowFixed(sm: 12, sd: 24, em: 12, ed: 26);
    expect(matchesCelebrationOverlay(r, DateTime(2028, 12, 25)), isTrue);
    expect(matchesCelebrationOverlay(r, DateTime(2028, 12, 23)), isFalse);
  });

  test('rejects invalid fixed span', () {
    final r = _rowFixed(sm: 5, sd: 10, em: 5, ed: 2);
    expect(matchesCelebrationOverlay(r, DateTime(2028, 5, 5)), isFalse);
  });

  test('respects year_exact when not repeating annually', () {
    final r = _rowFixed(
      sm: 6,
      sd: 1,
      repeatAnnual: false,
      y: 2027,
    );
    expect(matchesCelebrationOverlay(r, DateTime(2027, 6, 1)), isTrue);
    expect(matchesCelebrationOverlay(r, DateTime(2028, 6, 1)), isFalse);
  });

  test('disabled never matches', () {
    final r = DisplayOverlayScheduleRow(
      id: 'x',
      enabled: false,
      overlayKind: kOverlayKindHeartsRain,
      label: '',
      messagesJson: '[]',
      repeatAnnually: true,
      yearExact: null,
      startMonth: 5,
      startDay: 10,
      endMonth: null,
      endDay: null,
      nthWeekOfMonth: null,
      nthWeekday: null,
    );
    expect(matchesCelebrationOverlay(r, DateTime(2026, 5, 10)), isFalse);
  });
}
