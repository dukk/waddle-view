import 'dart:convert';

import 'package:drift/drift.dart';

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
  if (def == null) {
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
      final key = (a[def.accountKeyField] as String?)?.trim() ?? '';
      if (key.isNotEmpty) {
        yield key;
      }
    }
  } on Object {
    return;
  }
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
    for (final accountKey in accountKeysInIntegrationConfig(
      row.integrationType,
      row.configJson,
    )) {
      await db.into(db.integrationAccounts).insertOnConflictUpdate(
        IntegrationAccountsCompanion.insert(
          id: accountKey,
          accountType: accountTypeId,
          label: Value(accountKey),
          createdAtMs: nowMs,
        ),
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

Future<List<Map<String, dynamic>>> listIntegrationAccountsJson(
  AppDatabase db,
  SecretStore secrets,
) async {
  await syncIntegrationAccountsFromIntegrationConfigs(db);
  final rows = await db.select(db.integrationAccounts).get();
  rows.sort((a, b) => a.id.compareTo(b.id));
  final items = <Map<String, dynamic>>[];
  for (final row in rows) {
    final def = kIntegrationAccountTypes[row.accountType];
    items.add({
      'id': row.id,
      'account_type': row.accountType,
      'account_type_label': def?.label ?? row.accountType,
      'label': row.label ?? row.id,
      'signup_url': def?.signupUrl,
      'configured': await isIntegrationAccountConfigured(
        secrets,
        row.accountType,
        row.id,
      ),
      'integration_types': integrationTypesForAccountType(row.accountType),
    });
  }
  return items;
}

List<Map<String, dynamic>> integrationAccountTypesCatalogJson() {
  return [
    for (final def in kIntegrationAccountTypes.values)
      {
        'id': def.id,
        'label': def.label,
        'signup_url': def.signupUrl,
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
