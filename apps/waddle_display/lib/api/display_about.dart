import 'dart:convert';

import 'package:waddle_display/api/generated/display_about_data.dart';

export 'package:waddle_display/api/generated/display_about_data.dart'
    show
        kWaddleDisplayAppVersion,
        kWaddleDisplayBuildNumber,
        kDisplayProductLicenseId,
        kDisplayProductLicenseName,
        kDisplayProductLicenseUrl,
        kDisplayProductLicenseSummary,
        kDisplayThirdPartyLicensesText;

List<Map<String, dynamic>> parseDisplayAboutDependencies() {
  final decoded = jsonDecode(kDisplayAboutDependenciesJson);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
      .toList();
}

/// JSON body for public `GET /v1/about`.
Map<String, dynamic> buildDisplayAboutJson({String? thirdPartyLicenses}) {
  return {
    'app': 'waddle_display',
    'version': kWaddleDisplayAppVersion,
    'build': kWaddleDisplayBuildNumber,
    'product_license': {
      'id': kDisplayProductLicenseId,
      'name': kDisplayProductLicenseName,
      'url': kDisplayProductLicenseUrl,
      'summary': kDisplayProductLicenseSummary,
    },
    'dependencies': parseDisplayAboutDependencies(),
    'third_party_licenses': thirdPartyLicenses ?? kDisplayThirdPartyLicensesText,
  };
}

String encodeDisplayAboutJson({String? thirdPartyLicenses}) =>
    jsonEncode(buildDisplayAboutJson(thirdPartyLicenses: thirdPartyLicenses));
