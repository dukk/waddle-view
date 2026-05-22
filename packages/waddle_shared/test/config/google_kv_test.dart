import 'package:test/test.dart';
import 'package:waddle_shared/config/google_kv.dart';

void main() {
  test('google id helpers are stable per account key', () {
    expect(googleAccessTokenSecret('personal'), 'provider:access_token:google:personal');
    expect(googleRefreshTokenSecret('personal'), 'provider:refresh_token:google:personal');
    expect(googleCalendarEventSource('personal'), 'google_calendar:personal');
  });

  test('googleCalendarEventRowId and googlePhotosPhotoRowId are deterministic', () {
    final a = googleCalendarEventRowId('acct', 'cal1', 'evt1');
    final b = googleCalendarEventRowId('acct', 'cal1', 'evt1');
    expect(a, b);
    expect(a, isNot(equals(googleCalendarEventRowId('acct', 'cal1', 'evt2'))));

    final photo = googlePhotosPhotoRowId('acct', 'media-1');
    expect(photo.length, 64);
  });
}
