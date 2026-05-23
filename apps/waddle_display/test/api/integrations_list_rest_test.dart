import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../helpers/rest_auth_helper.dart';

Future<void> _insertIntegration(
  RestTestHarness h, {
  required String id,
  required String integrationType,
  bool enabled = true,
  int pollSeconds = 60,
}) async {
  await h.db
      .into(h.db.integrations)
      .insertOnConflictUpdate(
        IntegrationsCompanion.insert(
          id: id,
          integrationType: integrationType,
          enabled: Value(enabled),
          pollSeconds: Value(pollSeconds),
        ),
      );
}

void main() {
  test(
    'GET integrations without query returns full list (backward compat)',
    () async {
      final h = await RestTestHarness.start();
      addTearDown(h.dispose);
      await _insertIntegration(
        h,
        id: 'list_compat_a',
        integrationType: 'news_rss',
      );
      final res = await http.get(
        Uri.parse('${h.baseUrl}/v1/integrations'),
        headers: h.authHeaders,
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body.containsKey('total'), isFalse);
      final items = body['items'] as List<dynamic>;
      expect(
        items.cast<Map<String, dynamic>>().any(
          (e) => e['id'] == 'list_compat_a',
        ),
        isTrue,
      );
    },
  );

  test('enabled=true and enabled=false partition rows', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'en_on',
      integrationType: 'news_rss',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'en_off',
      integrationType: 'stock_finnhub',
      enabled: false,
    );

    final enabledRes = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations?enabled=true'),
      headers: h.authHeaders,
    );
    final enabledBody = jsonDecode(enabledRes.body) as Map<String, dynamic>;
    final enabledIds = (enabledBody['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(enabledIds, contains('en_on'));
    expect(enabledIds, isNot(contains('en_off')));

    final disabledRes = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations?enabled=false'),
      headers: h.authHeaders,
    );
    final disabledBody = jsonDecode(disabledRes.body) as Map<String, dynamic>;
    final disabledIds = (disabledBody['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(disabledIds, contains('en_off'));
    expect(disabledIds, isNot(contains('en_on')));
  });

  test('limit and offset paginate with total', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    for (var i = 0; i < 3; i++) {
      await _insertIntegration(
        h,
        id: 'page_$i',
        integrationType: 'news_rss',
        enabled: false,
        pollSeconds: 10 + i,
      );
    }

    final page0 = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=false&limit=2&offset=0&sort=id',
      ),
      headers: h.authHeaders,
    );
    final body0 = jsonDecode(page0.body) as Map<String, dynamic>;
    expect(body0['total'], 3);
    expect(body0['limit'], 2);
    expect(body0['offset'], 0);
    expect((body0['items'] as List).length, 2);

    final page1 = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=false&limit=2&offset=2&sort=id',
      ),
      headers: h.authHeaders,
    );
    final body1 = jsonDecode(page1.body) as Map<String, dynamic>;
    expect((body1['items'] as List).length, 1);
  });

  test('sort and order change item order', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'sort_b',
      integrationType: 'news_rss',
      enabled: true,
      pollSeconds: 90,
    );
    await _insertIntegration(
      h,
      id: 'sort_a',
      integrationType: 'joke_openai',
      enabled: true,
      pollSeconds: 10,
    );

    final asc = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=true&sort=poll_seconds&order=asc&limit=100',
      ),
      headers: h.authHeaders,
    );
    final ascItems = (jsonDecode(asc.body) as Map)['items'] as List;
    final ascIds = ascItems.map((e) => (e as Map)['id'] as String).toList();
    final aIdx = ascIds.indexOf('sort_a');
    final bIdx = ascIds.indexOf('sort_b');
    expect(aIdx, greaterThanOrEqualTo(0));
    expect(bIdx, greaterThanOrEqualTo(0));
    expect(aIdx, lessThan(bIdx));

    final desc = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=true&sort=poll_seconds&order=desc&limit=100',
      ),
      headers: h.authHeaders,
    );
    final descItems = (jsonDecode(desc.body) as Map)['items'] as List;
    final descIds = descItems.map((e) => (e as Map)['id'] as String).toList();
    expect(descIds.indexOf('sort_b'), lessThan(descIds.indexOf('sort_a')));
  });

  test('sort by integration_type_label uses integration_types.label', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await h.db
        .into(h.db.integrationTypes)
        .insertOnConflictUpdate(
          IntegrationTypesCompanion.insert(
            integrationType: 'news_rss',
            label: 'Zulu News',
          ),
        );
    await h.db
        .into(h.db.integrationTypes)
        .insertOnConflictUpdate(
          IntegrationTypesCompanion.insert(
            integrationType: 'joke_openai',
            label: 'Alpha Jokes',
          ),
        );
    await _insertIntegration(
      h,
      id: 'label_sort_b',
      integrationType: 'news_rss',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'label_sort_a',
      integrationType: 'joke_openai',
      enabled: true,
    );

    final asc = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=true&sort=integration_type_label&order=asc&limit=100',
      ),
      headers: h.authHeaders,
    );
    final ascIds = ((jsonDecode(asc.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toList();
    expect(
      ascIds.indexOf('label_sort_a'),
      lessThan(ascIds.indexOf('label_sort_b')),
    );
  });

  test('family and integration_type filters', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'fam_news',
      integrationType: 'news_rss',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'fam_cal',
      integrationType: 'calendar_google',
      enabled: true,
    );

    final familyRes = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=true&family=news&limit=100',
      ),
      headers: h.authHeaders,
    );
    final familyIds = ((jsonDecode(familyRes.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(familyIds, contains('fam_news'));
    expect(familyIds, isNot(contains('fam_cal')));

    final typeRes = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=true&integration_type=calendar_google&limit=100',
      ),
      headers: h.authHeaders,
    );
    final typeIds = ((jsonDecode(typeRes.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(typeIds, equals({'fam_cal'}));
  });

  test('q searches id and integration_type', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'needle_id',
      integrationType: 'news_rss',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'other',
      integrationType: 'joke_openai',
      enabled: true,
    );

    final res = await http.get(
      Uri.parse('${h.baseUrl}/v1/integrations?enabled=true&q=needle&limit=100'),
      headers: h.authHeaders,
    );
    final ids = ((jsonDecode(res.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(ids, equals({'needle_id'}));
  });

  test('secrets_configured and accounts_configured filters', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'ready_news',
      integrationType: 'news_rss',
      enabled: false,
    );
    await _insertIntegration(
      h,
      id: 'needs_google_setup',
      integrationType: 'calendar_google',
      enabled: false,
    );

    final secretsRes = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=false&secrets_configured=true&limit=100',
      ),
      headers: h.authHeaders,
    );
    final secretsIds = ((jsonDecode(secretsRes.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(secretsIds, contains('ready_news'));
    expect(secretsIds, isNot(contains('needs_google_setup')));

    final accountsRes = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=false&accounts_configured=true&limit=100',
      ),
      headers: h.authHeaders,
    );
    final accountsIds = ((jsonDecode(accountsRes.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(accountsIds, contains('ready_news'));
    expect(accountsIds, isNot(contains('needs_google_setup')));

    final missingRes = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?accounts_configured=false&limit=100',
      ),
      headers: h.authHeaders,
    );
    final missingIds = ((jsonDecode(missingRes.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(missingIds, contains('needs_google_setup'));
    expect(missingIds, isNot(contains('ready_news')));
  });

  test('accounts_configured partitions enabled lists exclusively', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'en_ok',
      integrationType: 'news_rss',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'en_needs_acct',
      integrationType: 'calendar_google',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'off_ok',
      integrationType: 'news_rss',
      enabled: false,
    );

    final enabledReady = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=true&accounts_configured=true&limit=100',
      ),
      headers: h.authHeaders,
    );
    final enabledReadyIds =
        ((jsonDecode(enabledReady.body) as Map)['items'] as List)
            .map((e) => (e as Map)['id'] as String)
            .toSet();
    expect(enabledReadyIds, contains('en_ok'));
    expect(enabledReadyIds, isNot(contains('en_needs_acct')));

    final availableReady = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=false&accounts_configured=true&limit=100',
      ),
      headers: h.authHeaders,
    );
    final availableReadyIds =
        ((jsonDecode(availableReady.body) as Map)['items'] as List)
            .map((e) => (e as Map)['id'] as String)
            .toSet();
    expect(availableReadyIds, contains('off_ok'));
    expect(availableReadyIds, isNot(contains('en_needs_acct')));

    final missing = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?accounts_configured=false&limit=100',
      ),
      headers: h.authHeaders,
    );
    final missingIds = ((jsonDecode(missing.body) as Map)['items'] as List)
        .map((e) => (e as Map)['id'] as String)
        .toSet();
    expect(missingIds, contains('en_needs_acct'));
    expect(missingIds, isNot(contains('en_ok')));
    expect(missingIds, isNot(contains('off_ok')));
  });

  test('accounts_configured=false paginates with stable total', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'miss_a',
      integrationType: 'calendar_google',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'miss_b',
      integrationType: 'calendar_outlook',
      enabled: false,
    );
    await _insertIntegration(
      h,
      id: 'miss_c',
      integrationType: 'photo_pexels',
      enabled: false,
    );

    final page0 = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?accounts_configured=false&limit=1&offset=0&sort=id',
      ),
      headers: h.authHeaders,
    );
    final body0 = jsonDecode(page0.body) as Map<String, dynamic>;
    expect(body0['total'], 3);
    expect((body0['items'] as List).length, 1);

    final page1 = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?accounts_configured=false&limit=1&offset=1&sort=id',
      ),
      headers: h.authHeaders,
    );
    final body1 = jsonDecode(page1.body) as Map<String, dynamic>;
    expect(body1['total'], 3);
    expect((body1['items'] as List).length, 1);

    final ids = [
      ...((body0['items'] as List).map((e) => (e as Map)['id'] as String)),
      ...((body1['items'] as List).map((e) => (e as Map)['id'] as String)),
    ];
    expect(ids.toSet().length, 2);
  });

  test(
    'accounts_configured reflects stored token via view without column refresh',
    () async {
      final h = await RestTestHarness.start();
      addTearDown(h.dispose);
      const accountId = 'ms-home';
      await _insertIntegration(
        h,
        id: 'outlook_home',
        integrationType: 'calendar_outlook',
        enabled: false,
      );
      await h.db
          .into(h.db.integrationAccounts)
          .insertOnConflictUpdate(
            IntegrationAccountsCompanion.insert(
              id: accountId,
              accountType: kIntegrationAccountTypeMicrosoftGraph,
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await h.db
          .into(h.db.integrationAccountLinks)
          .insertOnConflictUpdate(
            IntegrationAccountLinksCompanion.insert(
              integrationId: 'outlook_home',
              accountId: accountId,
            ),
          );
      await h.secrets.write(
        microsoftGraphAccessTokenSecret(accountId),
        'test-token',
      );

      final missingRes = await http.get(
        Uri.parse(
          '${h.baseUrl}/v1/integrations?accounts_configured=false&limit=100',
        ),
        headers: h.authHeaders,
      );
      final missingIds = ((jsonDecode(missingRes.body) as Map)['items'] as List)
          .map((e) => (e as Map)['id'] as String)
          .toSet();
      expect(missingIds, isNot(contains('outlook_home')));

      final readyRes = await http.get(
        Uri.parse(
          '${h.baseUrl}/v1/integrations?enabled=false&accounts_configured=true&limit=100',
        ),
        headers: h.authHeaders,
      );
      final readyIds = ((jsonDecode(readyRes.body) as Map)['items'] as List)
          .map((e) => (e as Map)['id'] as String)
          .toSet();
      expect(readyIds, contains('outlook_home'));

      final item =
          ((readyRes.body.isNotEmpty ? jsonDecode(readyRes.body) : {})
                  as Map)['items']
              as List;
      final outlook = item.cast<Map<String, dynamic>>().firstWhere(
        (e) => e['id'] == 'outlook_home',
      );
      expect(outlook['accounts_configured'], isTrue);
    },
  );

  test('facets=family returns counts', () async {
    final h = await RestTestHarness.start();
    addTearDown(h.dispose);
    await _insertIntegration(
      h,
      id: 'facet_n1',
      integrationType: 'news_rss',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'facet_n2',
      integrationType: 'news_facebook',
      enabled: true,
    );
    await _insertIntegration(
      h,
      id: 'facet_j',
      integrationType: 'joke_openai',
      enabled: true,
    );

    final res = await http.get(
      Uri.parse(
        '${h.baseUrl}/v1/integrations?enabled=true&facets=family&limit=100',
      ),
      headers: h.authHeaders,
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final facets = body['facets'] as Map<String, dynamic>;
    final family = facets['family'] as Map<String, dynamic>;
    expect(family['news'], 2);
    expect(family['joke'], 1);
  });
}
