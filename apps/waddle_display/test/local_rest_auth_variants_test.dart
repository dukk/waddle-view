import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers/rest_auth_helper.dart';

void main() {
  test('accepts Authorization bearer session token', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final r = await http.get(
      Uri.parse('${h.baseUrl}/v1/providers'),
      headers: {'Authorization': 'Bearer ${h.token}'},
    );
    expect(r.statusCode, 200);
  });
}
