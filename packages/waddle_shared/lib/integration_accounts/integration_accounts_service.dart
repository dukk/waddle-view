import 'dart:convert';

import 'package:drift/drift.dart';

import '../integrations/integration_kv_repository.dart';
import '../integrations/integration_kv_types.dart';
import '../persistence/database.dart';
import '../secrets/secret_store.dart';
import 'integration_account_catalog.dart';
import 'oauth_provider_catalog.dart';
import 'oauth_sign_in_alerts.dart';

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
  /// When true (operator create), refresh [label] on conflict. Sync from integration
  /// configs must leave an existing operator label unchanged.
  bool overwriteLabelOnConflict = false,
}) async {
  final companion = IntegrationAccountsCompanion.insert(
    id: accountId,
    accountType: accountTypeId,
    label: Value(label),
    createdAtMs: nowMs,
  );
  if (overwriteLabelOnConflict) {
    await db.into(db.integrationAccounts).insertOnConflictUpdate(companion);
    return;
  }
  await db.into(db.integrationAccounts).insert(
    companion,
    onConflict: DoUpdate(
      (old) => IntegrationAccountsCompanion(
        accountType: Value(accountTypeId),
      ),
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

Future<bool> _integrationHasLinkedAccountOfType(
  AppDatabase db,
  String integrationId,
  String accountTypeId,
) async {
  final links = await (db.select(db.integrationAccountLinks)
        ..where((t) => t.integrationId.equals(integrationId)))
      .get();
  for (final link in links) {
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(link.accountId)))
        .getSingleOrNull();
    if (account?.accountType == accountTypeId) {
      return true;
    }
  }
  return false;
}

Future<void> _unlinkIntegrationAccount(
  AppDatabase db, {
  required String integrationId,
  required String accountId,
}) async {
  await (db.delete(db.integrationAccountLinks)
        ..where(
          (t) =>
              t.integrationId.equals(integrationId) &
              t.accountId.equals(accountId),
        ))
      .go();
}

/// True when every [requiredAccountTypes] entry has at least one linked account
/// with a configured secret (see [listAccountsForIntegrationJson] items).
bool integrationLinkedAccountsJsonConfigured(
  List<Map<String, dynamic>> linked,
  List<String> requiredAccountTypes,
) {
  if (requiredAccountTypes.isEmpty) {
    return true;
  }
  for (final typeId in requiredAccountTypes) {
    final satisfied = linked.any(
      (a) => a['account_type'] == typeId && a['configured'] == true,
    );
    if (!satisfied) {
      return false;
    }
  }
  return true;
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

/// Backfills [Integrations.requiresAccounts] and [Integrations.accountsReady] after schema 23.
///
/// Without [secrets], [accountsReady] is conservative (`false` when accounts are required).
Future<void> backfillIntegrationsAccountsReadyColumns(
  AppDatabase db, {
  SecretStore? secrets,
}) async {
  final rows = await db.select(db.integrations).get();
  for (final row in rows) {
    final requires =
        integrationAccountTypesRequiredForIntegration(row.integrationType).isNotEmpty;
    var ready = !requires;
    if (requires && secrets != null) {
      ready = await integrationAccountsSatisfiedForEnable(
        secrets,
        db,
        row.id,
        row.integrationType,
        syncAccountLinks: false,
      );
    } else if (requires) {
      ready = false;
    }
    await (db.update(db.integrations)..where((t) => t.id.equals(row.id))).write(
      IntegrationsCompanion(
        requiresAccounts: Value(requires),
        accountsReady: Value(ready),
      ),
    );
  }
}

Future<void> refreshIntegrationAccountsReady(
  SecretStore secrets,
  AppDatabase db,
  String integrationId, {
  bool syncAccountLinks = false,
}) async {
  if (syncAccountLinks) {
    await syncIntegrationAccountLinks(db, secrets: secrets);
    return;
  }
  final row = await (db.select(db.integrations)
        ..where((t) => t.id.equals(integrationId)))
      .getSingleOrNull();
  if (row == null) {
    return;
  }
  final requires =
      integrationAccountTypesRequiredForIntegration(row.integrationType).isNotEmpty;
  final ready = requires
      ? await integrationAccountsSatisfiedForEnable(
          secrets,
          db,
          integrationId,
          row.integrationType,
          syncAccountLinks: false,
        )
      : true;
  await (db.update(db.integrations)..where((t) => t.id.equals(integrationId))).write(
    IntegrationsCompanion(
      requiresAccounts: Value(requires),
      accountsReady: Value(ready),
    ),
  );
}

Future<void> refreshAllIntegrationsAccountsReady(
  SecretStore secrets,
  AppDatabase db,
) async {
  final rows = await db.select(db.integrations).get();
  for (final row in rows) {
    await refreshIntegrationAccountsReady(
      secrets,
      db,
      row.id,
      syncAccountLinks: false,
    );
  }
}

Future<void> syncIntegrationAccountLinks(
  AppDatabase db, {
  SecretStore? secrets,
}) async {
  await syncIntegrationAccountsFromIntegrationConfigs(db);
  final rows = await db.select(db.integrations).get();
  for (final row in rows) {
    final accountTypeId = accountTypeForIntegrationType(row.integrationType);
    if (accountTypeId == null) {
      continue;
    }
    if (integrationTypeUsesApiKeyAccount(row.integrationType)) {
      if (!await _integrationHasLinkedAccountOfType(db, row.id, accountTypeId)) {
        await _linkIntegrationAccount(
          db,
          integrationId: row.id,
          accountId: defaultApiKeyAccountIdForIntegration(row.id),
        );
      } else {
        final legacyId = defaultApiKeyAccountIdForIntegration(row.id);
        final links = await (db.select(db.integrationAccountLinks)
              ..where((t) => t.integrationId.equals(row.id)))
            .get();
        final hasNonLegacyLink =
            links.any((link) => link.accountId != legacyId);
        if (hasNonLegacyLink) {
          await _unlinkIntegrationAccount(
            db,
            integrationId: row.id,
            accountId: legacyId,
          );
        }
      }
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
  if (secrets != null) {
    await refreshAllIntegrationsAccountsReady(secrets, db);
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
  final preferredTypeId = accountTypeForIntegrationType(row.integrationType);
  for (final link in links) {
    final account = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals(link.accountId)))
        .getSingleOrNull();
    if (account == null) {
      continue;
    }
    if (preferredTypeId != null && account.accountType != preferredTypeId) {
      continue;
    }
    final def = kIntegrationAccountTypes[account.accountType];
    if (def == null) {
      continue;
    }
    final token = await secrets.read(def.accessTokenSecretKey(account.id));
    if (token != null && token.trim().isNotEmpty) {
      return token;
    }
  }
  if (links.isEmpty && integrationTypeUsesApiKeyAccount(row.integrationType)) {
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

Future<bool> integrationAccountsSatisfiedForEnable(
  SecretStore secrets,
  AppDatabase db,
  String integrationId,
  String integrationType, {
  bool syncAccountLinks = true,
}) async {
  final requiredTypes =
      integrationAccountTypesRequiredForIntegration(integrationType);
  if (requiredTypes.isEmpty) {
    return true;
  }
  final links = syncAccountLinks
      ? await linkedAccountsForIntegration(db, integrationId)
      : await (db.select(db.integrationAccountLinks)
            ..where((t) => t.integrationId.equals(integrationId)))
          .get();
  if (links.isEmpty) {
    return false;
  }
  for (final typeId in requiredTypes) {
    var satisfied = false;
    for (final link in links) {
      final account = await (db.select(db.integrationAccounts)
            ..where((t) => t.id.equals(link.accountId)))
          .getSingleOrNull();
      if (account == null || account.accountType != typeId) {
        continue;
      }
      if (await isIntegrationAccountConfigured(
        secrets,
        account.accountType,
        account.id,
      )) {
        satisfied = true;
        break;
      }
    }
    if (!satisfied) {
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
    final configured = await isIntegrationAccountConfigured(
      secrets,
      row.accountType,
      row.id,
    );
    if (!_includeAccountInOperatorList(row.accountType, configured)) {
      continue;
    }
    final linkedIntegrationIds = integrationsByAccount[row.id] ?? const [];
    final signInStatus = await oauthSignInStatusForAccount(
      db,
      accountId: row.id,
      accountTypeId: row.accountType,
      configured: configured,
    );
    final item = <String, dynamic>{
      'id': row.id,
      'account_type': row.accountType,
      'account_type_label': def?.label ?? row.accountType,
      'label': row.label ?? row.id,
      'signup_url': def?.signupUrl,
      'supports_oauth_sign_in': def?.supportsOAuthSignIn ?? false,
      'configured': configured,
      'integration_types': integrationTypesForAccountType(row.accountType),
      'integration_ids': linkedIntegrationIds,
    };
    final statusJson = oauthSignInStatusJson(signInStatus);
    if (statusJson != null) {
      item['oauth_sign_in_status'] = statusJson;
    }
    items.add(item);
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
    final configured = await isIntegrationAccountConfigured(
      secrets,
      account.accountType,
      account.id,
    );
    final signInStatus = await oauthSignInStatusForAccount(
      db,
      accountId: account.id,
      accountTypeId: account.accountType,
      configured: configured,
    );
    final linkedItem = <String, dynamic>{
      'account_id': account.id,
      'account_type': account.accountType,
      'account_type_label': def?.label ?? account.accountType,
      'label': account.label ?? account.id,
      'signup_url': def?.signupUrl,
      'supports_oauth_sign_in': def?.supportsOAuthSignIn ?? false,
      'configured': configured,
      'required': requiredTypes.contains(account.accountType),
    };
    final statusJson = oauthSignInStatusJson(signInStatus);
    if (statusJson != null) {
      linkedItem['oauth_sign_in_status'] = statusJson;
    }
    out.add(linkedItem);
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

bool _includeAccountInOperatorList(String accountTypeId, bool configured) {
  final def = kIntegrationAccountTypes[accountTypeId];
  if (def == null) {
    return false;
  }
  if (def.supportsOAuthSignIn) {
    return true;
  }
  return configured;
}

String? _mergeOAuthAccountKeyIntoConfig(
  String? configJson,
  String accountKeyField,
  String accountKey,
) {
  Map<String, dynamic> root;
  try {
    if (configJson == null || configJson.trim().isEmpty) {
      root = <String, dynamic>{};
    } else {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map<String, dynamic>) {
        root = <String, dynamic>{};
      } else {
        root = decoded;
      }
    }
  } on Object {
    root = <String, dynamic>{};
  }
  final accountsRaw = root['accounts'];
  final accounts = accountsRaw is List<dynamic>
      ? List<dynamic>.from(accountsRaw)
      : <dynamic>[];
  final exists = accounts.any((a) {
    if (a is! Map<String, dynamic>) {
      return false;
    }
    return (a[accountKeyField] as String?)?.trim() == accountKey;
  });
  if (exists) {
    return configJson;
  }
  accounts.add({accountKeyField: accountKey, 'sources': <dynamic>[]});
  root['accounts'] = accounts;
  return jsonEncode(root);
}

Future<void> _appendOAuthAccountKeyToIntegrations(
  AppDatabase db,
  String accountTypeId,
  String accountKey,
) async {
  final def = kIntegrationAccountTypes[accountTypeId];
  final field = def?.accountKeyField;
  if (field == null) {
    return;
  }
  for (final integrationType in integrationTypesForAccountType(accountTypeId)) {
    final rows = await (db.select(db.integrations)
          ..where((t) => t.integrationType.equals(integrationType)))
        .get();
    for (final row in rows) {
      final merged = _mergeOAuthAccountKeyIntoConfig(
        row.configJson,
        field,
        accountKey,
      );
      if (merged == null || merged == row.configJson) {
        continue;
      }
      await (db.update(db.integrations)..where((t) => t.id.equals(row.id))).write(
        IntegrationsCompanion(configJson: Value(merged)),
      );
    }
  }
}

/// Creates or updates a shared account and links integrations that use [accountTypeId].
Future<String> createOperatorIntegrationAccount(
  AppDatabase db,
  SecretStore secrets, {
  required String accountTypeId,
  String? accountKey,
  String? label,
}) async {
  final def = kIntegrationAccountTypes[accountTypeId];
  if (def == null) {
    throw ArgumentError('unknown_account_type');
  }
  final oauthProvider = oauthProviderForAccountType(accountTypeId);
  if (oauthProvider != null) {
    final clientId = await secrets.read(oauthProvider.clientIdStorageKey);
    if (clientId == null || clientId.trim().isEmpty) {
      throw StateError('oauth_client_id_required');
    }
  }
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  late final String accountId;
  if (def.supportsOAuthSignIn) {
    final key = accountKey?.trim() ?? '';
    if (key.isEmpty) {
      throw ArgumentError('account_key_required');
    }
    accountId = key;
  } else {
    final key = accountKey?.trim() ?? '';
    accountId = key.isNotEmpty ? key : accountTypeId;
  }
  final displayLabel =
      (label?.trim().isNotEmpty == true) ? label!.trim() : accountId;
  await _upsertIntegrationAccount(
    db,
    accountId: accountId,
    accountTypeId: accountTypeId,
    label: displayLabel,
    nowMs: nowMs,
    overwriteLabelOnConflict: true,
  );
  for (final integrationType in integrationTypesForAccountType(accountTypeId)) {
    final rows = await (db.select(db.integrations)
          ..where((t) => t.integrationType.equals(integrationType)))
        .get();
    for (final row in rows) {
      await _linkIntegrationAccount(
        db,
        integrationId: row.id,
        accountId: accountId,
      );
      if (!def.supportsOAuthSignIn) {
        final legacyId = defaultApiKeyAccountIdForIntegration(row.id);
        if (legacyId != accountId) {
          await _unlinkIntegrationAccount(
            db,
            integrationId: row.id,
            accountId: legacyId,
          );
        }
      }
    }
  }
  if (def.supportsOAuthSignIn) {
    await _appendOAuthAccountKeyToIntegrations(db, accountTypeId, accountId);
    await syncIntegrationAccountLinks(db, secrets: secrets);
  } else {
    await refreshAllIntegrationsAccountsReady(secrets, db);
  }
  return accountId;
}

/// Thrown when [deleteOperatorIntegrationAccount] is called without [confirm]
/// while [integrationIds] integrations still reference the account.
class IntegrationAccountInUseException implements Exception {
  IntegrationAccountInUseException(this.integrationIds);

  final List<String> integrationIds;

  @override
  String toString() => 'IntegrationAccountInUseException($integrationIds)';
}

/// Outcome of a successful operator account delete.
class DeleteOperatorIntegrationAccountResult {
  const DeleteOperatorIntegrationAccountResult({
    required this.disabledIntegrationIds,
  });

  final List<String> disabledIntegrationIds;
}

String? _removeOAuthAccountKeyFromConfig(
  String? configJson,
  String accountKeyField,
  String accountKey,
) {
  if (configJson == null || configJson.trim().isEmpty) {
    return configJson;
  }
  Map<String, dynamic> root;
  try {
    final decoded = jsonDecode(configJson);
    if (decoded is! Map<String, dynamic>) {
      return configJson;
    }
    root = decoded;
  } on Object {
    return configJson;
  }
  final accountsRaw = root['accounts'];
  if (accountsRaw is! List<dynamic>) {
    return configJson;
  }
  final accounts = <dynamic>[];
  var changed = false;
  for (final a in accountsRaw) {
    if (a is! Map<String, dynamic>) {
      accounts.add(a);
      continue;
    }
    if ((a[accountKeyField] as String?)?.trim() == accountKey) {
      changed = true;
      continue;
    }
    accounts.add(a);
  }
  if (!changed) {
    return configJson;
  }
  root['accounts'] = accounts;
  return jsonEncode(root);
}

Future<void> _removeOAuthAccountKeyFromIntegrations(
  AppDatabase db,
  String accountKeyField,
  String accountKey,
) async {
  final rows = await db.select(db.integrations).get();
  for (final row in rows) {
    final merged = _removeOAuthAccountKeyFromConfig(
      row.configJson,
      accountKeyField,
      accountKey,
    );
    if (merged == null || merged == row.configJson) {
      continue;
    }
    await (db.update(db.integrations)..where((t) => t.id.equals(row.id))).write(
      IntegrationsCompanion(configJson: Value(merged)),
    );
  }
}

Future<void> _clearOAuthSignInKvForAccount(
  AppDatabase db,
  String accountId,
  String accountTypeId,
) async {
  final kv = IntegrationKvRepository(db);
  switch (accountTypeId) {
    case kIntegrationAccountTypeGoogle:
    case kIntegrationAccountTypeMicrosoftGraph:
      await kv.deleteAccountKey(accountId, kIntegrationLastDevicePromptKey);
    default:
      break;
  }
}

/// Deletes a shared account, clears its secrets, and disables integrations that
/// depended on it. Pass [confirm] when [IntegrationAccountInUseException] would
/// otherwise be thrown.
Future<DeleteOperatorIntegrationAccountResult> deleteOperatorIntegrationAccount(
  AppDatabase db,
  SecretStore secrets, {
  required String accountId,
  bool confirm = false,
}) async {
  await syncIntegrationAccountLinks(db, secrets: secrets);
  final account = await (db.select(db.integrationAccounts)
        ..where((t) => t.id.equals(accountId)))
      .getSingleOrNull();
  if (account == null) {
    throw ArgumentError('not_found');
  }
  final linkRows = await (db.select(db.integrationAccountLinks)
        ..where((t) => t.accountId.equals(accountId)))
      .get();
  final integrationIds = linkRows.map((l) => l.integrationId).toList()..sort();
  if (integrationIds.isNotEmpty && !confirm) {
    throw IntegrationAccountInUseException(integrationIds);
  }

  final def = kIntegrationAccountTypes[account.accountType];
  final accountKeyField = def?.accountKeyField;
  if (accountKeyField != null) {
    await _removeOAuthAccountKeyFromIntegrations(
      db,
      accountKeyField,
      accountId,
    );
  }
  if (def != null) {
    await secrets.delete(def.accessTokenSecretKey(accountId));
  }
  await dismissOAuthSignInAlertsForAccount(
    db,
    accountId: accountId,
    accountTypeId: account.accountType,
  );
  await _clearOAuthSignInKvForAccount(db, accountId, account.accountType);

  await (db.delete(db.integrationAccounts)..where((t) => t.id.equals(accountId)))
      .go();

  final disabled = <String>[];
  for (final integrationId in integrationIds) {
    final row = await (db.select(db.integrations)
          ..where((t) => t.id.equals(integrationId)))
        .getSingleOrNull();
    if (row == null || !row.enabled) {
      continue;
    }
    await (db.update(db.integrations)..where((t) => t.id.equals(integrationId)))
        .write(const IntegrationsCompanion(enabled: Value(false)));
    disabled.add(integrationId);
  }
  disabled.sort();
  await refreshAllIntegrationsAccountsReady(secrets, db);
  return DeleteOperatorIntegrationAccountResult(
    disabledIntegrationIds: disabled,
  );
}

Future<void> updateOperatorIntegrationAccountLabel(
  AppDatabase db,
  String accountId, {
  required String label,
}) async {
  final trimmed = label.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('label_required');
  }
  final updated = await (db.update(db.integrationAccounts)
        ..where((t) => t.id.equals(accountId)))
      .write(IntegrationAccountsCompanion(label: Value(trimmed)));
  if (updated == 0) {
    throw ArgumentError('not_found');
  }
}

Future<List<Map<String, dynamic>>> oauthProvidersStatusJson(
  SecretStore secrets,
) async {
  final out = <Map<String, dynamic>>[];
  for (final provider in kOAuthProviders) {
    final stored = await secrets.read(provider.clientIdStorageKey);
    final configured = stored != null && stored.trim().isNotEmpty;
    out.add({
      'id': provider.id,
      'label': provider.label,
      'account_type': provider.accountTypeId,
      'client_id_configured': configured,
    });
  }
  return out;
}

Future<void> putOAuthProviderClientId(
  SecretStore secrets,
  String providerId,
  String value,
) async {
  final provider = oauthProviderById(providerId);
  if (provider == null) {
    throw ArgumentError('unknown_provider');
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('value_must_be_non_empty');
  }
  await secrets.write(provider.clientIdStorageKey, trimmed);
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
  final kv = IntegrationKvRepository(db);
  switch (account.accountType) {
    case kIntegrationAccountTypeGoogle:
    case kIntegrationAccountTypeMicrosoftGraph:
      await kv.upsertAccount(
        accountId: accountId,
        key: kIntegrationLastDevicePromptKey,
        value: '0',
        valueType: kIntegrationKvTypeIntMs,
      );
    default:
      break;
  }
}
