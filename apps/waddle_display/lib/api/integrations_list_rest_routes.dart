import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:waddle_display/api/integration_secrets_rest_routes.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_configured_sql.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/integration_types_seed.dart';
import 'package:waddle_shared/secrets/secret_store.dart';
import 'package:waddle_display/api/rest_include_params.dart';

const _jsonHeaders = {'content-type': 'application/json'};

/// Provider `integration_type` prefix before the first `_` (e.g. `calendar_google` → `calendar`).
String integrationDataFamily(String integrationType) {
  final t = integrationType.trim();
  final u = t.indexOf('_');
  if (u <= 0) {
    return t.isNotEmpty ? t : 'other';
  }
  return t.substring(0, u);
}

void registerIntegrationsListRestRoutes(
  Router r, {
  required AppDatabase db,
  required SecretStore secrets,
}) {
  r.get('/v1/integrations', (Request req) => listIntegrations(req, db: db, secrets: secrets));
}

class IntegrationsListParams {
  IntegrationsListParams({
    this.enabled,
    this.limit,
    this.offset = 0,
    this.sort = IntegrationsSort.id,
    this.orderAsc = true,
    this.family,
    this.integrationType,
    this.q,
    this.secretsConfigured,
    this.accountsConfigured,
    this.facetsFamily = false,
  });

  final bool? enabled;
  final int? limit;
  final int offset;
  final IntegrationsSort sort;
  final bool orderAsc;
  final String? family;
  final String? integrationType;
  final String? q;
  final bool? secretsConfigured;
  final bool? accountsConfigured;
  final bool facetsFamily;

  bool get paginated => enabled != null || limit != null;

  static IntegrationsListParams parse(Request req) {
    final qp = req.url.queryParameters;
    final enabledRaw = qp['enabled']?.trim().toLowerCase();
    bool? enabled;
    if (enabledRaw == 'true') {
      enabled = true;
    } else if (enabledRaw == 'false') {
      enabled = false;
    }

    final limitRaw = int.tryParse(qp['limit'] ?? '');
    final int? limit = limitRaw?.clamp(1, 100);

    final offset = (int.tryParse(qp['offset'] ?? '') ?? 0).clamp(0, 1 << 30);

    final sortRaw = (qp['sort'] ?? 'id').trim().toLowerCase();
    final sort = IntegrationsSort.values.firstWhere(
      (s) => s.queryValue == sortRaw,
      orElse: () => IntegrationsSort.id,
    );

    final orderRaw = (qp['order'] ?? 'asc').trim().toLowerCase();
    final orderAsc = orderRaw != 'desc';

    final family = _trimOrNull(qp['family']);
    final integrationType = _trimOrNull(qp['integration_type']);
    final q = _likeNeedle(qp['q']);

    final secretsConfigured = _parseBoolOrNull(qp['secrets_configured']);
    final accountsConfigured = _parseBoolOrNull(qp['accounts_configured']);

    final facetsRaw = (qp['facets'] ?? '').trim().toLowerCase();
    final facetsFamily = facetsRaw == 'family';

    return IntegrationsListParams(
      enabled: enabled,
      limit: enabled != null && limit == null ? 25 : limit,
      offset: offset,
      sort: sort,
      orderAsc: orderAsc,
      family: family,
      integrationType: integrationType,
      q: q,
      secretsConfigured: secretsConfigured,
      accountsConfigured: accountsConfigured,
      facetsFamily: facetsFamily,
    );
  }
}

enum IntegrationsSort {
  id('id'),
  integrationType('integration_type'),
  pollSeconds('poll_seconds'),
  enabled('enabled');

  const IntegrationsSort(this.queryValue);
  final String queryValue;
}

String? _trimOrNull(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  return t;
}

bool? _parseBoolOrNull(String? raw) {
  final t = raw?.trim().toLowerCase();
  if (t == null || t.isEmpty) return null;
  if (t == 'true') return true;
  if (t == 'false') return false;
  return null;
}

String? _likeNeedle(String? raw) {
  var s = (raw ?? '').trim();
  if (s.length > 200) {
    s = s.substring(0, 200);
  }
  final stripped = s.replaceAll('%', '').replaceAll('_', '').trim();
  if (stripped.isEmpty) return null;
  return stripped;
}

Future<Response> listIntegrations(
  Request req, {
  required AppDatabase db,
  required SecretStore secrets,
}) async {
  final params = IntegrationsListParams.parse(req);
  final includeDocs = includeConfigSchemaFromRequest(req);
  await syncIntegrationAccountLinks(db);
  final accountsConfiguredMap = await integrationAccountsConfiguredViewMap(db);

  if (!params.paginated) {
    final rows = await _queryIntegrationRows(db, params);
    final enriched = <Map<String, dynamic>>[];
    for (final e in rows) {
      enriched.add(
        await _enrichIntegrationRow(
          db,
          secrets,
          e,
          accountsConfigured: accountsConfiguredMap[e.id] ?? false,
          includeConfigDocs: includeDocs,
        ),
      );
    }
    var filtered = enriched;
    if (params.secretsConfigured != null) {
      filtered = filtered
          .where((m) => m['secrets_configured'] == params.secretsConfigured)
          .toList();
    }
    if (params.accountsConfigured != null) {
      filtered = filtered
          .where((m) => m['accounts_configured'] == params.accountsConfigured)
          .toList();
    }
    return Response.ok(
      jsonEncode({'items': filtered}),
      headers: _jsonHeaders,
    );
  }

  if (params.secretsConfigured != null) {
    return _listIntegrationsPaginatedWithSecretsFilter(
      db,
      secrets,
      params,
      includeConfigDocs: includeDocs,
    );
  }

  final limit = params.limit ?? 25;
  final total = await _countIntegrationRows(db, params);
  final rows = await _queryIntegrationRows(
    db,
    params,
    limit: limit,
    offset: params.offset,
  );
  final page = <Map<String, dynamic>>[];
  for (final e in rows) {
    page.add(
      await _enrichIntegrationRow(
        db,
        secrets,
        e,
        accountsConfigured: accountsConfiguredMap[e.id] ?? false,
        includeConfigDocs: includeDocs,
      ),
    );
  }

  final body = <String, dynamic>{
    'items': page,
    'total': total,
    'limit': limit,
    'offset': params.offset,
  };

  if (params.facetsFamily) {
    body['facets'] = {
      'family': await _familyFacetCounts(db, secrets, params),
    };
  }

  return Response.ok(jsonEncode(body), headers: _jsonHeaders);
}

Future<Response> _listIntegrationsPaginatedWithSecretsFilter(
  AppDatabase db,
  SecretStore secrets,
  IntegrationsListParams params, {
  bool includeConfigDocs = false,
}) async {
  await syncIntegrationAccountLinks(db);
  final accountsConfiguredMap = await integrationAccountsConfiguredViewMap(db);
  final rows = await _queryIntegrationRows(db, params);
  final enriched = <Map<String, dynamic>>[];
  for (final e in rows) {
    enriched.add(
      await _enrichIntegrationRow(
        db,
        secrets,
        e,
        accountsConfigured: accountsConfiguredMap[e.id] ?? false,
        includeConfigDocs: includeConfigDocs,
      ),
    );
  }

  var filtered = enriched
      .where((m) => m['secrets_configured'] == params.secretsConfigured)
      .toList();
  if (params.accountsConfigured != null) {
    filtered = filtered
        .where((m) => m['accounts_configured'] == params.accountsConfigured)
        .toList();
  }

  final limit = params.limit ?? 25;
  final offset = params.offset;
  final start = offset.clamp(0, filtered.length);
  final end = (start + limit).clamp(0, filtered.length);
  final page = filtered.sublist(start, end);

  final body = <String, dynamic>{
    'items': page,
    'total': filtered.length,
    'limit': limit,
    'offset': offset,
  };

  if (params.facetsFamily) {
    body['facets'] = {
      'family': await _familyFacetCounts(db, secrets, params),
    };
  }

  return Response.ok(jsonEncode(body), headers: _jsonHeaders);
}

Future<int> _countIntegrationRows(
  AppDatabase db,
  IntegrationsListParams params,
) async {
  final countExpr = db.integrations.id.count();
  final query = db.selectOnly(db.integrations)
    ..addColumns([countExpr])
    ..where(_integrationWhere(db, db.integrations, params));
  final row = await query.getSingle();
  return row.read(countExpr)!;
}

Future<List<Integration>> _queryIntegrationRows(
  AppDatabase db,
  IntegrationsListParams params, {
  int? limit,
  int offset = 0,
}) async {
  final query = db.select(db.integrations)
    ..where((t) => _integrationWhere(db, t, params))
    ..orderBy([(t) => _orderingTerm(t, params)]);
  if (limit != null) {
    query.limit(limit, offset: offset);
  }
  return query.get();
}

Expression<bool> _integrationWhere(
  AppDatabase db,
  $IntegrationsTable t,
  IntegrationsListParams params,
) {
  Expression<bool> expr = const Constant(true);
  if (params.enabled != null) {
    expr = expr & t.enabled.equals(params.enabled!);
  }
  if (params.integrationType != null) {
    expr = expr & t.integrationType.equals(params.integrationType!);
  }
  if (params.family != null) {
    final f = params.family!;
    expr = expr &
        (t.integrationType.equals(f) | t.integrationType.like('${f}_%'));
  }
  if (params.q != null) {
    final pattern = '%${params.q!}%';
    expr = expr &
        (t.id.like(pattern) | t.integrationType.like(pattern));
  }
  if (params.accountsConfigured == true) {
    expr = expr &
        const CustomExpression<bool>(
          '(NOT EXISTS (SELECT 1 FROM integration_types it '
          'WHERE it.integration_type = integrations.integration_type '
          'AND it.requires_accounts = 1) '
          'OR EXISTS (SELECT 1 FROM v_integration_accounts_configured v '
          'WHERE v.integration_id = integrations.id AND v.accounts_configured = 1))',
        );
  } else if (params.accountsConfigured == false) {
    expr = expr &
        const CustomExpression<bool>(
          '(EXISTS (SELECT 1 FROM integration_types it '
          'WHERE it.integration_type = integrations.integration_type '
          'AND it.requires_accounts = 1) '
          'AND NOT EXISTS (SELECT 1 FROM v_integration_accounts_configured v '
          'WHERE v.integration_id = integrations.id AND v.accounts_configured = 1))',
        );
  }
  return expr;
}

OrderingTerm _orderingTerm($IntegrationsTable t, IntegrationsListParams params) {
  final dir = params.orderAsc ? OrderingMode.asc : OrderingMode.desc;
  switch (params.sort) {
    case IntegrationsSort.integrationType:
      return OrderingTerm(expression: t.integrationType, mode: dir);
    case IntegrationsSort.pollSeconds:
      return OrderingTerm(expression: t.pollSeconds, mode: dir);
    case IntegrationsSort.enabled:
      return OrderingTerm(expression: t.enabled, mode: dir);
    case IntegrationsSort.id:
      return OrderingTerm(expression: t.id, mode: dir);
  }
}

Future<Map<String, dynamic>> _enrichIntegrationRow(
  AppDatabase db,
  SecretStore secrets,
  Integration e, {
  required bool accountsConfigured,
  bool includeConfigDocs = false,
}) async {
  final requiredAccountTypes =
      integrationAccountTypesRequiredForIntegration(e.integrationType);
  final typeRow = await (db.select(db.integrationTypes)
        ..where((t) => t.integrationType.equals(e.integrationType)))
      .getSingleOrNull();
  final schemaRaw = typeRow?.configJsonSchema ??
      providerConfigJsonDocForType(e.integrationType).schema;
  return {
    'id': e.id,
    'integration_type': e.integrationType,
    if (typeRow != null) 'integration_type_label': typeRow.label,
    'enabled': e.enabled,
    'poll_seconds': e.pollSeconds,
    'config_json': _jsonDecodeLoose(e.configJson),
    if (includeConfigDocs) 'config_json_schema': _jsonDecodeLoose(schemaRaw),
    'secrets_configured': await integrationSecretsConfigured(
      secrets,
      e.id,
      e.integrationType,
    ),
    'accounts_configured': accountsConfigured,
    'linked_accounts': await listAccountsForIntegrationJson(
      db,
      secrets,
      e.id,
    ),
    'required_account_types': [
      for (final typeId in requiredAccountTypes)
        {
          'account_type': typeId,
          'account_type_label':
              kIntegrationAccountTypes[typeId]?.label ?? typeId,
          'signup_url': kIntegrationAccountTypes[typeId]?.signupUrl ?? '',
          'supports_oauth_sign_in':
              kIntegrationAccountTypes[typeId]?.supportsOAuthSignIn ?? false,
        },
    ],
  };
}

/// Facet counts for [params] with [family] filter cleared.
Future<Map<String, int>> _familyFacetCounts(
  AppDatabase db,
  SecretStore secrets,
  IntegrationsListParams params,
) async {
  final facetParams = IntegrationsListParams(
    enabled: params.enabled,
    family: null,
    integrationType: params.integrationType,
    q: params.q,
    secretsConfigured: params.secretsConfigured,
    accountsConfigured: params.accountsConfigured,
    sort: params.sort,
    orderAsc: params.orderAsc,
  );
  final rows = await _queryIntegrationRows(db, facetParams);
  final counts = <String, int>{};
  for (final e in rows) {
    var include = true;
    if (params.secretsConfigured != null) {
      final secretsOk = await integrationSecretsConfigured(
        secrets,
        e.id,
        e.integrationType,
      );
      if (secretsOk != params.secretsConfigured) {
        include = false;
      }
    }
    if (include && params.accountsConfigured != null) {
      final requires = await integrationTypeRequiresAccounts(db, e.integrationType);
      final accountsOk = !requires ||
          (await integrationAccountsConfiguredFromView(db, e.id));
      if (accountsOk != params.accountsConfigured) {
        include = false;
      }
    }
    if (!include) continue;
    final family = integrationDataFamily(e.integrationType);
    counts[family] = (counts[family] ?? 0) + 1;
  }
  return counts;
}

dynamic _jsonDecodeLoose(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(raw);
  } catch (_) {
    return raw;
  }
}
