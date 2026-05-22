import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/api/display_about.dart';

void main() {
  test('buildDisplayAboutJson includes version, license, and dependencies', () {
    final body = buildDisplayAboutJson(thirdPartyLicenses: 'test notices');

    expect(body['app'], 'waddle_display');
    expect(body['version'], kWaddleDisplayAppVersion);
    expect(body['build'], kWaddleDisplayBuildNumber);
    final license = body['product_license'] as Map<String, dynamic>;
    expect(license['id'], 'ONC');
    expect(license['url'], isNotEmpty);
    final deps = body['dependencies'] as List<dynamic>;
    expect(deps, isNotEmpty);
    expect(body['third_party_licenses'], 'test notices');
  });

  test('parseDisplayAboutDependencies returns structured rows', () {
    final deps = parseDisplayAboutDependencies();
    expect(deps.any((d) => d['name'] == 'flutter'), isTrue);
    expect(deps.any((d) => d['name'] == 'waddle_shared'), isTrue);
  });
}
