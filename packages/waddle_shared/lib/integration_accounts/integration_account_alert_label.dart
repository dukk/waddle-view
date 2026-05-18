import 'package:waddle_shared/persistence/database.dart';

/// Operator-visible account name for OAuth device-code alerts on the display.
///
/// Prefers the [IntegrationAccounts.label] entered in the controller; falls back
/// to [accountId] when unset.
Future<String> integrationAccountAlertLabel(
  AppDatabase db,
  String accountId,
) async {
  final row = await (db.select(db.integrationAccounts)
        ..where((t) => t.id.equals(accountId)))
      .getSingleOrNull();
  return integrationAccountAlertLabelFromRow(row, accountId);
}

/// Same as [integrationAccountAlertLabel] when the account row is already loaded.
String integrationAccountAlertLabelFromRow(
  IntegrationAccount? row,
  String accountId,
) {
  final label = row?.label?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return accountId;
}
