import 'package:test/test.dart';
import 'package:waddle_integrations/calendar_mealviewer/mealviewer_api_client.dart';

void main() {
  test('formatMealviewerApiDate uses MM-DD-YYYY', () {
    expect(
      MealviewerApiClient.formatMealviewerApiDate(DateTime.utc(2026, 5, 19)),
      '05-19-2026',
    );
  });

  test('MealviewerSchoolSummary parses physical location json', () {
    final s = MealviewerSchoolSummary.fromPhysicalLocationJson({
      'physicalLocationLookup': 'ElmwoodElementary',
      'name': 'Elmwood Elementary',
      'city': 'Hopkinton',
      'state': 'Massachusetts',
      'districtLookup': 'Hopkinton',
    });
    expect(s, isNotNull);
    expect(s!.schoolSlug, 'ElmwoodElementary');
    expect(s.label, 'Elmwood Elementary');
    expect(s.districtSlug, 'Hopkinton');
  });

  test('MealviewerDistrictSummary uses username when districtLookup is dash', () {
    final d = MealviewerDistrictSummary.fromCustomerJson({
      'districtLookup': '-',
      'username': 'HopkintonMA',
      'email': 'Hopkinton, MA',
      'stateCode': 'MA',
    });
    expect(d, isNotNull);
    expect(d!.districtSlug, 'HopkintonMA');
    expect(d.label, 'Hopkinton, MA');
  });
}
