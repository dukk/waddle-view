import 'dart:convert';

import 'package:drift/drift.dart';

import '../config/google_kv.dart';
import '../config/microsoft_graph_kv.dart';
import '../persistence/database.dart';
import '../secrets/secret_store.dart';
import 'integration_account_catalog.dart';

/// Parses account keys referenced in integration [configJson] for OAuth types.
Iterable<String> accountKeysInIntegrationConfig(
  String integrationType,
  String? configJson,
) sync* {
  final accountTypeId = accountTypeForIntegrationType(integrationType);
  if (accountTypeId == null) {
    return;
  }
  final def = kIntegrationAccountTypes[accountTypeId];
  if (def == null || def.accountKeyField == null) {
    return;
  }
  if (configJson == null || configJson.trim().isEmpty) {
    return;
  }
  try {
    final root = jsonDecode(configJson);
    if (root is! Map<String, dynamic>) {
      return;
    }
    final accountsRaw = root['accounts'];
    if (accountsRaw is! List<dynamic>) {
      return;
    }
    for (final a in accountsRaw) {
      if (a is! Map<String, dynamic>) {
        continue;
      }
      final key = (a[def.accountKeyField!] as String?)?.trim() ?? '';
      if (key.isNotEmpty) {
        yield key;
      }
    }
  } on Object {
    return;
  }
}

Future<void> _upsertIntegrationAccount(
  AppDatabase db, {
  required String accountId,
  required String accountTypeId,
  required String label,
  required int nowMs,
}) async {
  await db.into(db.integrationAccounts).insertOnConflictUpdate(
    IntegrationAccountsCompanion.insert(
      id: accountId,
      accountType: accountTypeId,
      label: Value(label),
      createdAtMs: nowMs,
    ),
  );
}

Future<void> _linkIntegrationAccount(
  AppDatabase db, {
  required String integrationId,
  required String accountId,
}) async {
  await db.into(db.integrationAccountLinks).insertOnConflictUpdate(
    IntegrationAccountLinksCompanion.insert(
      integrationId: integrationId,
      accountId: accountId,
    ),
  );
}

Future<void> syncIntegrationAccountsFromIntegrationConfigs(
  AppDatabase db,
) async {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final rows = await db.select(db.integrations).get();
  for (final row in rows) {
    final accountTypeId = accountTypeForIntegrationType(row.integrationType);
    if (accountTypeId == null) {
      continue;
    }
    if (integrationTypeUsesApiKeyAccount(row.integrationType)) {
      final accountId = defaultApiKeyAccountIdForIntegration(row.id);
      await _upsertIntegrationAccount(
        db,
        accountId: accountId,
        accountTypeId: accountTypeId,
        label: row.id,
        nowMs: nowMs,
      );
      continue;
    }
    for (final accountKey in accountKeysInIntegrationConfig(
      row.integrationType,
      row.configJson,
    )) {
      await _upsertIntegrationAccount(
        db,
        accountId: accountKey,
        accountTypeId: accountTypeId,
        label: accountKey,
        nowMs: nowMs,
      );
    }
  }
}

Future<void> syncIntegrationAccountLinks(AppDatabase db) async {
  await syncIntegrationAccountsFromIntegrationConfigs(db);
  final rows = await db.select(db.integrations).get();
  for (final row in rows) {
    final accountTypeId = accountTypeForIntegrationType(row.integrationType);
    if (accountTypeId == null) {
      continue;
    }
    if (integrationTypeUsesApiKeyAccount(row.integrationType)) {
      await _linkIntegrationAccount(
        db,
        integrationId: row.id,
        accountId: defaultApiKeyAccountIdForIntegration(row.id),
      );
      continue;
    }
    for (final accountKey in accountKeysInIntegrationConfig(
      row.integrationType,
      row.configJson,
    )) {
      await _linkIntegrationAccount(
        db,
        integrationId: row.id,
        accountId: accountKey,
      );
    }
  }
}

Future<bool> isIntegrationAccountConfigured(
  SecretStore secrets,
  String accountTypeId,
  String accountId,
) async {
  final def = kIntegrationAccountTypes[accountTypeId];
  if (def == null) {
    return false;
  }
  final token = await secrets.read(def.accessTokenSecretKey(accountId));
  return token != null && token.trim().isNotEmpty;
}

Future<List<IntegrationAccountLink>> linkedAccountsForIntegration(
  AppDatabase db,
  String integrationId,
) async {
  await syncIntegrationAccountLinks(db);
  return (db.select(db.integrationAccountLinks)
        ..where((t) => t.integrationId.equals(integrationId)))
      .get();
}

Future<String?> readAccessTokenForIntegration(
  SecretStore secrets,
  AppDatabase db,
  String integrationId,
) async {
  final row = await (db.select(db.integrations)
        ..where((t) => t.id.equals(integrationId)))
      .getSingleOrNull();
  if (row == null) {
    return null;
  }
  final links = await linkedAccountsForIntegration(db, integrationId);
  if (links.isEmpty) {
    if (integrationTypeUsesApiKeyAccount(row.integrationType)) {
      final accountTypeId = accountTypeForIntegrationType(row.integrationType);
      if (accountTypeId == null) {
        return null;
      }
      final def = kIntegrationAccountTypes[accountTypeId];
      if (def == null) {
        return null;
      }
      return secrets.read(
        def.accessTokenSecretKey(defaultApiKeyAccountIdForIntegration(row.id)),
      );
    }
    return null;
  }
  final account = await (db.select(db.integrationAccounts)
        ..where((t) => t.id.equals(links.first.accountId)))
      .getSingleOrNull();
  if (account == null) {
    return null;
  }
  final def = kIntegrationAccountTypes[account.accountType];
  if (def == null) {
    return null;
  }
  return secrets.read(def.accessTokenSecretKey(account.id));
}

Future<bool> integrationAccountsSatisfiedForEnable(
  SecretStore secrets,
  AppDatabase db,
  String integrationId,
  String integrationType,
) async {
  final requiredTypes =
      integrationAccountTypesRequiredForIntegration(integrationType);
  if (requiredTypes.isEmpty) {
    return true;
  }
  final links = await linkedAccountsForIntegration(db, integrationId);
  if (links.isEmpty) {
    return false;
  }
  for (final link in links) {
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(link.accountId)))
        .getSingleOrNull();
    if (account == null) {
      return false;
    }
    if (!requiredTypes.contains(account.accountType)) {
      continue;
    }
    if (!await isIntegrationAccountConfigured(
      secrets,
      account.accountType,
      account.id,
    )) {
      return false;
    }
  }
  return true;
}

Future<List<Map<String, dynamic>>> listIntegrationAccountsJson(
  AppDatabase db,
  SecretStore secrets,
) async {
  await syncIntegrationAccountLinks(db);
  final rows = await db.select(db.integrationAccounts).get();
  rows.sort((a, b) => a.id.compareTo(b.id));
  final linkRows = await db.select(db.integrationAccountLinks).get();
  final integrationsByAccount = <String, List<String>>{};
  for (final link in linkRows) {
    integrationsByAccount
        .putIfAbsent(link.accountId, () => [])
        .add(link.integrationId);
  }
  for (final ids in integrationsByAccount.values) {
    ids.sort();
  }
  final items = <Map<String, dynamic>>[];
  for (final row in rows) {
    final def = kIntegrationAccountTypes[row.accountType];
    final linkedIntegrationIds = integrationsByAccount[row.id] ?? const [];
    items.add({
      'id': row.id,
      'account_type': row.accountType,
      'account_type_label': def?.label ?? row.accountType,
      'label': row.label ?? row.id,
      'signup_url': def?.signupUrl,
      'supports_oauth_sign_in': def?.supportsOAuthSignIn ?? false,
      'configured': await isIntegrationAccountConfigured(
        secrets,
        row.accountType,
        row.id,
      ),
      'integration_types': integrationTypesForAccountType(row.accountType),
      'integration_ids': linkedIntegrationIds,
    });
  }
  return items;
}

Future<List<Map<String, dynamic>>> listAccountsForIntegrationJson(
  AppDatabase db,
  SecretStore secrets,
  String integrationId,
) async {
  final row = await (db.select(db.integrations)
        ..where((t) => t.id.equals(integrationId)))
      .getSingleOrNull();
  if (row == null) {
    return [];
  }
  await syncIntegrationAccountLinks(db);
  final requiredTypes =
      integrationAccountTypesRequiredForIntegration(row.integrationType);
  final links = await linkedAccountsForIntegration(db, integrationId);
  final out = <Map<String, dynamic>>[];
  for (final link in links) {
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(link.accountId)))
        .getSingleOrNull();
    if (account == null) {
      continue;
    }
    final def = kIntegrationAccountTypes[account.accountType];
    out.add({
      'account_id': account.id,
      'account_type': account.accountType,
      'account_type_label': def?.label ?? account.accountType,
      'label': account.label ?? account.id,
      'signup_url': def?.signupUrl,
      'supports_oauth_sign_in': def?.supportsOAuthSignIn ?? false,
      'configured': await isIntegrationAccountConfigured(
        secrets,
        account.accountType,
        account.id,
      ),
      'required': requiredTypes.contains(account.accountType),
    });
  }
  return out;
}

List<Map<String, dynamic>> integrationAccountTypesCatalogJson() {
  return [
    for (final def in kIntegrationAccountTypes.values)
      {
        'id': def.id,
        'label': def.label,
        'signup_url': def.signupUrl,
        'supports_oauth_sign_in': def.supportsOAuthSignIn,
        'integration_types': integrationTypesForAccountType(def.id),
      },
  ];
}

List<Map<String, dynamic>> integrationAccountRequirementsCatalogJson() {
  final out = <Map<String, dynamic>>[];
  for (final entry in kIntegrationAccountRequirementsByType.entries) {
    for (final accountTypeId in entry.value) {
      final def = kIntegrationAccountTypes[accountTypeId];
      out.add({
        'integration_type': entry.key,
        'account_type': accountTypeId,
        'account_type_label': def?.label ?? accountTypeId,
        'signup_url': def?.signupUrl ?? '',
        'supports_oauth_sign_in': def?.supportsOAuthSignIn ?? false,
      });
    }
  }
  out.sort(
    (a, b) => (a['integration_type'] as String).compareTo(
      b['integration_type'] as String,
    ),
  );
  return out;
}

/// Clears OAuth device-code cooldown so the next collect can prompt sign-in.
Future<void> requestOAuthSignInForAccount(
  AppDatabase db,
  String accountId,
) async {
  final account = await (db.select(db.integrationAccounts)
        ..where((t) => t.id.equals(accountId)))
      .getSingleOrNull();
  if (account == null) {
    return;
  }
  switch (account.accountType) {
    case kIntegrationAccountTypeGoogle:
      await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kGoogleCalendarLastDevicePromptKvKey(accountId),
          value: '0',
        ),
      );
    case kIntegrationAccountTypeMicrosoftGraph:
      await db.into(db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kOutlookCalendarLastDevicePromptKvKey(accountId),
          value: '0',
        ),
      );
    default:
      break;
  }
}
