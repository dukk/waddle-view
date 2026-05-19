import 'package:drift/drift.dart';

import '../config/google_kv.dart';
import '../config/microsoft_graph_kv.dart';
import '../persistence/database.dart';
import 'integration_account_alert_label.dart';
import 'integration_account_catalog.dart';

/// Operator-visible OAuth sign-in phase for controller UI.
enum OAuthSignInStatus {
  pending,
  expired,
}

/// [Alerts.source] for device-code prompts for [accountTypeId], or null.
String? oauthAlertSourceForAccountType(String accountTypeId) {
  switch (accountTypeId) {
    case kIntegrationAccountTypeGoogle:
      return kGoogleOAuthAlertSource;
    case kIntegrationAccountTypeMicrosoftGraph:
      return kMicrosoftGraphOAuthAlertSource;
    default:
      return null;
  }
}

/// Whether [text] (alert title/body) refers to [accountId] / [accountLabel].
bool oauthAlertMatchesAccount(
  String text,
  String accountId,
  String accountLabel,
) {
  if (text.contains(accountLabel)) {
    return true;
  }
  return accountLabel != accountId && text.contains(accountId);
}

bool _isActiveOAuthAlert(DashboardAlert row, DateTime now) {
  if (row.dismissedAt != null) {
    return false;
  }
  final exp = row.expiresAt;
  if (exp != null && !exp.isAfter(now)) {
    return false;
  }
  return true;
}

/// Non-dismissed OAuth sign-in alerts for [accountId] that are still within
/// [expiresAt] (if set).
Future<List<DashboardAlert>> activeOAuthSignInAlertsForAccount(
  AppDatabase db, {
  required String accountId,
  required String alertSource,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  final accountLabel = await integrationAccountAlertLabel(db, accountId);
  final rows = await (db.select(db.alerts)
        ..where((t) => t.source.equals(alertSource))
        ..where((t) => t.dismissedAt.isNull()))
      .get();
  return [
    for (final row in rows)
      if (_isActiveOAuthAlert(row, clock) &&
          (oauthAlertMatchesAccount(row.title, accountId, accountLabel) ||
              oauthAlertMatchesAccount(row.body, accountId, accountLabel)))
        row,
  ];
}

/// Sets [dismissedAt] on all non-dismissed OAuth sign-in alerts for [accountId].
Future<void> dismissOAuthSignInAlertsForAccount(
  AppDatabase db, {
  required String accountId,
  required String accountTypeId,
  DateTime? dismissedAt,
}) async {
  final source = oauthAlertSourceForAccountType(accountTypeId);
  if (source == null) {
    return;
  }
  final accountLabel = await integrationAccountAlertLabel(db, accountId);
  final when = dismissedAt ?? DateTime.now();
  final rows = await (db.select(db.alerts)
        ..where((t) => t.source.equals(source))
        ..where((t) => t.dismissedAt.isNull()))
      .get();
  for (final row in rows) {
    if (!oauthAlertMatchesAccount(row.title, accountId, accountLabel) &&
        !oauthAlertMatchesAccount(row.body, accountId, accountLabel)) {
      continue;
    }
    await (db.update(db.alerts)..where((t) => t.id.equals(row.id))).write(
      AlertsCompanion(dismissedAt: Value(when)),
    );
  }
}

/// Sign-in phase when the account is not yet configured; null when configured
/// or not an OAuth account type.
Future<OAuthSignInStatus?> oauthSignInStatusForAccount(
  AppDatabase db, {
  required String accountId,
  required String accountTypeId,
  required bool configured,
  DateTime? now,
}) async {
  if (configured) {
    return null;
  }
  final source = oauthAlertSourceForAccountType(accountTypeId);
  if (source == null) {
    return null;
  }
  final active = await activeOAuthSignInAlertsForAccount(
    db,
    accountId: accountId,
    alertSource: source,
    now: now,
  );
  if (active.isNotEmpty) {
    return OAuthSignInStatus.pending;
  }
  return OAuthSignInStatus.expired;
}

/// JSON value for REST: `'pending'`, `'expired'`, or omitted when null.
String? oauthSignInStatusJson(OAuthSignInStatus? status) {
  return switch (status) {
    OAuthSignInStatus.pending => 'pending',
    OAuthSignInStatus.expired => 'expired',
    null => null,
  };
}
