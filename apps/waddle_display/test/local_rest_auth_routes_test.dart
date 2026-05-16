import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/persistence/tables.dart';

import 'helpers/rest_auth_helper.dart';

void main() {
  test('auth me returns permissions', () async {
    final h = await RestTestHarness.start(role: kUserRoleOperator);
    addTearDown(h.dispose);
    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/auth/me'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final perms = (body['permissions'] as List).cast<String>();
    expect(perms, contains('screens.write'));
    expect(perms, isNot(contains('users.manage')));
  });

  test('logout invalidates session', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final logout = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/logout'),
      headers: h.authHeaders,
    );
    expect(logout.statusCode, 200);
    final after = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations'),
      headers: h.authHeaders,
    );
    expect(after.statusCode, 401);
  });

  test('admin can list and create users', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final list = await http.get(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
    );
    expect(list.statusCode, 200);
    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
      body: jsonEncode({
        'username': 'bob',
        'password': 'bob-password-12',
        'role': kUserRoleViewer,
      }),
    );
    expect(create.statusCode, 200);
    final body = jsonDecode(create.body) as Map<String, dynamic>;
    expect(body['user']['username'], 'bob');
  });

  test('operator cannot list users', () async {
    final h = await RestTestHarness.start(role: kUserRoleOperator);
    addTearDown(h.dispose);
    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 403);
  });

  test('operator can patch own display_name only', () async {
    final h = await RestTestHarness.start(role: kUserRoleOperator);
    addTearDown(h.dispose);
    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/users/user_test_admin'),
      headers: h.authHeaders,
      body: jsonEncode({'display_name': 'Operator display'}),
    );
    expect(res.statusCode, 200);
    final user =
        (jsonDecode(res.body) as Map<String, dynamic>)['user'] as Map<String, dynamic>;
    expect(user['display_name'], 'Operator display');
  });

  test('operator cannot patch own role via self profile', () async {
    final h = await RestTestHarness.start(role: kUserRoleOperator);
    addTearDown(h.dispose);
    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/users/user_test_admin'),
      headers: h.authHeaders,
      body: jsonEncode({
        'display_name': 'X',
        'role': kUserRoleAdmin,
      }),
    );
    expect(res.statusCode, 400);
  });

  test('operator cannot patch another user', () async {
    final admin = await RestTestHarness.start();
    addTearDown(admin.dispose);
    final victim = await http.post(
      Uri.parse('${admin.baseUrl}/v1/users'),
      headers: admin.authHeaders,
      body: jsonEncode({
        'username': 'victim',
        'password': 'victim-password-12',
        'role': kUserRoleViewer,
      }),
    );
    expect(victim.statusCode, 200);
    final victimId =
        (jsonDecode(victim.body) as Map<String, dynamic>)['user']['id'] as String;

    await http.post(
      Uri.parse('${admin.baseUrl}/v1/users'),
      headers: admin.authHeaders,
      body: jsonEncode({
        'username': 'someop',
        'password': 'someop-password-12',
        'role': kUserRoleOperator,
      }),
    );
    final opLogin = await http.post(
      Uri.parse('${admin.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'someop',
        'password': 'someop-password-12',
      }),
    );
    expect(opLogin.statusCode, 200);
    final opToken =
        (jsonDecode(opLogin.body) as Map<String, dynamic>)['session_token'] as String;

    final res = await http.patch(
      Uri.parse('${admin.baseUrl}/v1/users/$victimId'),
      headers: {
        'Authorization': 'Bearer $opToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'display_name': 'nope'}),
    );
    expect(res.statusCode, 403);
  });

  test('self password change', () async {
    final h = await RestTestHarness.start(username: 'pwuser', password: 'old-password-12');
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/users/user_test_admin/password'),
      headers: h.authHeaders,
      body: jsonEncode({'password': 'new-password-12'}),
    );
    expect(res.statusCode, 200);
    final login = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'pwuser', 'password': 'new-password-12'}),
    );
    expect(login.statusCode, 200);
  });

  test('oauth providers lists configured env', () async {
    final h = await RestTestHarness.start(
      env: {
        'WADDLE_GOOGLE_CLIENT_ID': 'g',
        'WADDLE_MICROSOFT_GRAPH_CLIENT_ID': 'm',
        'WADDLE_APPLE_CLIENT_ID': 'a',
      },
    );
    addTearDown(h.dispose);
    final res = await http.get(Uri.parse('${h.baseUrl}/v1/auth/oauth/providers'));
    expect(res.statusCode, 200);
    final items = (jsonDecode(res.body) as Map)['items'] as List;
    expect(items.length, 3);
  });

  test('oauth start returns not implemented', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/oauth/google/start'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    expect(res.statusCode, 501);
  });

  test('login rejects bad password', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'testadmin', 'password': 'wrong'}),
    );
    expect(res.statusCode, 401);
  });

  test('patch and disable user', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
      body: jsonEncode({
        'username': 'patchme',
        'password': 'patchme-pass-12',
        'role': kUserRoleOperator,
      }),
    );
    final id =
        (jsonDecode(create.body) as Map<String, dynamic>)['user']['id'] as String;
    final patch = await http.patch(
      Uri.parse('${h.baseUrl}/v1/users/$id'),
      headers: h.authHeaders,
      body: jsonEncode({'role': kUserRoleViewer, 'display_name': 'Patched'}),
    );
    expect(patch.statusCode, 200);
    final del = await http.delete(
      Uri.parse('${h.baseUrl}/v1/users/$id'),
      headers: h.authHeaders,
    );
    expect(del.statusCode, 200);
  });

  test('username_taken returns 409', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final body = jsonEncode({
      'username': 'dup',
      'password': 'dup-password-12',
      'role': kUserRoleViewer,
    });
    expect(
      (await http.post(
        Uri.parse('${h.baseUrl}/v1/users'),
        headers: h.authHeaders,
        body: body,
      )).statusCode,
      200,
    );
    expect(
      (await http.post(
        Uri.parse('${h.baseUrl}/v1/users'),
        headers: h.authHeaders,
        body: body,
      )).statusCode,
      409,
    );
  });

  test('cannot patch bootstrap user', () async {
    final h = await BootstrapRestTestHarness.start();
    addTearDown(h.dispose);
    final display = await h.users.findByUsername(kBootstrapUsername);
    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/users/${display!.id}'),
      headers: h.authHeaders,
      body: jsonEncode({'disabled': true}),
    );
    expect(res.statusCode, 403);
  });

  test('GET permissions matches me', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/auth/permissions'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 200);
    expect(res.body, contains('"permissions"'));
  });

  test('oauth callback returns 501', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.get(Uri.parse('${h.baseUrl}/v1/auth/oauth/google/callback'));
    expect(res.statusCode, 501);
  });

  test('login invalid json returns 400', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: 'not-json',
    );
    expect(res.statusCode, 400);
  });

  test('admin can reset another user password', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
      body: jsonEncode({
        'username': 'resettarget',
        'password': 'reset-target-12',
        'role': kUserRoleViewer,
      }),
    );
    final id =
        (jsonDecode(create.body) as Map<String, dynamic>)['user']['id'] as String;
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/users/$id/password'),
      headers: h.authHeaders,
      body: jsonEncode({'password': 'new-reset-target'}),
    );
    expect(res.statusCode, 200);
  });

  test('password too short returns 400', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/users/user_test_admin/password'),
      headers: h.authHeaders,
      body: jsonEncode({'password': 'short'}),
    );
    expect(res.statusCode, 400);
  });

  test('patch missing user returns 404', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/users/no_such_user'),
      headers: h.authHeaders,
      body: jsonEncode({'role': kUserRoleViewer}),
    );
    expect(res.statusCode, 404);
  });

  test('create user invalid json', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
      body: '{',
    );
    expect(res.statusCode, 400);
  });

  test('create user invalid role', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
      body: jsonEncode({
        'username': 'badrole',
        'password': 'badrole-pass-12',
        'role': 'superuser',
      }),
    );
    expect(res.statusCode, 400);
  });

  test('viewer cannot change another users password', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
      body: jsonEncode({
        'username': 'viewonly',
        'password': 'viewonly-pass12',
        'role': kUserRoleViewer,
      }),
    );
    expect(create.statusCode, 200);
    final login = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'viewonly', 'password': 'viewonly-pass12'}),
    );
    final viewerToken =
        (jsonDecode(login.body) as Map)['session_token'] as String;
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/users/user_test_admin/password'),
      headers: {
        'Authorization': 'Bearer $viewerToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': 'nope-not-allowed'}),
    );
    expect(res.statusCode, 403);
  });

  test('disable missing user returns 404', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.delete(
      Uri.parse('${h.baseUrl}/v1/users/no_such_user'),
      headers: h.authHeaders,
    );
    expect(res.statusCode, 404);
  });

  test('password change for missing user returns 404', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/users/no_such_user/password'),
      headers: h.authHeaders,
      body: jsonEncode({'password': 'valid-password'}),
    );
    expect(res.statusCode, 404);
  });

  test('auth me requires session', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.get(Uri.parse('${h.baseUrl}/v1/auth/me'));
    expect(res.statusCode, 401);
  });

  test('login requires username and password', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': '', 'password': ''}),
    );
    expect(res.statusCode, 400);
  });

  test('login unknown username returns 401', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'nobody', 'password': 'any-password'}),
    );
    expect(res.statusCode, 401);
  });

  test('patch user invalid json returns 400', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/users/user_test_admin'),
      headers: h.authHeaders,
      body: '{',
    );
    expect(res.statusCode, 400);
  });

  test('patch invalid role returns 400', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final create = await http.post(
      Uri.parse('${h.baseUrl}/v1/users'),
      headers: h.authHeaders,
      body: jsonEncode({
        'username': 'patchrole',
        'password': 'patchrole-pass12',
        'role': kUserRoleViewer,
      }),
    );
    final id =
        (jsonDecode(create.body) as Map<String, dynamic>)['user']['id'] as String;
    final res = await http.patch(
      Uri.parse('${h.baseUrl}/v1/users/$id'),
      headers: h.authHeaders,
      body: jsonEncode({'role': 'not-a-role'}),
    );
    expect(res.statusCode, 400);
  });

  test('register viewer disabled when registration secret unset', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/register-viewer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'v',
        'password': 'password12',
        'registration_secret': 'x',
      }),
    );
    expect(res.statusCode, 403);
    expect(res.body, contains('viewer_registration_disabled'));
  });

  test('register viewer requires at least one named operator', () async {
    final h = await BootstrapRestTestHarness.start(
      env: {'WADDLE_VIEWER_REGISTRATION_SECRET': 'invite-secret'},
    );
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/register-viewer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'v',
        'password': 'password12',
        'registration_secret': 'invite-secret',
      }),
    );
    expect(res.statusCode, 403);
    expect(res.body, contains('viewer_registration_requires_operator'));
  });

  test('register viewer rejects wrong secret', () async {
    final h = await RestTestHarness.start(
      env: {'WADDLE_VIEWER_REGISTRATION_SECRET': 'correct'},
    );
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/register-viewer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'v',
        'password': 'password12',
        'registration_secret': 'wrong',
      }),
    );
    expect(res.statusCode, 401);
  });

  test('register viewer creates viewer user and session', () async {
    final h = await RestTestHarness.start(
      env: {'WADDLE_VIEWER_REGISTRATION_SECRET': 'invite-secret'},
    );
    addTearDown(h.dispose);
    final res = await http.post(
      Uri.parse('${h.baseUrl}/v1/auth/register-viewer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'from_qr',
        'password': 'password12',
        'registration_secret': 'invite-secret',
      }),
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['user']['username'], 'from_qr');
    expect(body['user']['role'], kUserRoleViewer);
    expect(body['session_token'], isNotEmpty);
    final me = await http.get(
      Uri.parse('${h.baseUrl}/v1/auth/me'),
      headers: {
        'Authorization': 'Bearer ${body['session_token']}',
      },
    );
    expect(me.statusCode, 200);
  });
}
