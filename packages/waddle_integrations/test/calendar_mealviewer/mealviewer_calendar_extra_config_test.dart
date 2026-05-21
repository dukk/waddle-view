import 'package:test/test.dart';
import 'package:waddle_integrations/calendar_mealviewer/mealviewer_calendar_extra_config.dart';
import 'package:waddle_shared/config/calendar_integration_defaults.dart';
import 'package:waddle_shared/config/mealviewer_kv.dart';

void main() {
  test('MealviewerCalendarExtraConfig parses schools and window', () {
    final c = MealviewerCalendarExtraConfig.parse(
      '{"baseUrl":"https://api.mealviewer.com","schools":[{"schoolSlug":"Elmwood Elementary",'
      '"label":"Elmwood","districtSlug":"Hopkinton","categoryIds":["school","lunch"]}],'
      '"pastDays":7,"futureDays":14}',
    );
    expect(c.baseUrl, 'https://api.mealviewer.com');
    expect(c.schools.length, 1);
    expect(c.schools.single.schoolSlug, 'ElmwoodElementary');
    expect(c.schools.single.label, 'Elmwood');
    expect(c.schools.single.districtSlug, 'Hopkinton');
    expect(c.schools.single.categoryIds, ['school', 'lunch']);
    expect(c.pastDays, 7);
    expect(c.futureDays, 14);
  });

  test('empty config uses defaults', () {
    final c = MealviewerCalendarExtraConfig.parse(null);
    expect(c.baseUrl, kMealviewerApiDefaultBaseUrl);
    expect(c.schools, isEmpty);
    expect(c.pastDays, kCalendarSyncPastFutureDaysDefault);
    expect(c.futureDays, kCalendarSyncPastFutureDaysDefault);
  });

  test('normalizeMealviewerSchoolSlug removes spaces', () {
    expect(normalizeMealviewerSchoolSlug('Foo Bar'), 'FooBar');
    expect(normalizeMealviewerSchoolSlug('  '), isNull);
  });
}
