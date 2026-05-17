import 'package:waddle_shared/persistence/tables.dart';

/// Permission strings exposed to REST clients and enforced on routes.
abstract final class WaddlePermission {
  static const usersManage = 'users.manage';
  static const screensRead = 'screens.read';
  static const screensWrite = 'screens.write';
  static const integrationsRead = 'integrations.read';
  static const integrationsWrite = 'integrations.write';
  static const curatorRead = 'curator.read';
  static const curatorWrite = 'curator.write';
  static const tickerRead = 'ticker.read';
  static const tickerWrite = 'ticker.write';
  static const overlaysRead = 'overlays.read';
  static const overlaysWrite = 'overlays.write';
  static const alertsRead = 'alerts.read';
  static const alertsWrite = 'alerts.write';
  static const contentModerate = 'content.moderate';
  /// Paginated catalog GETs without suppressed rows or suppression filters (`power_viewer`).
  static const contentCatalogRead = 'content.catalog_read';
  static const rejectTermsManage = 'reject_terms.manage';
  static const navigationControl = 'navigation.control';
  static const telemetryRead = 'telemetry.read';
  static const metaRead = 'meta.read';
}

const _adminPermissions = <String>{
  WaddlePermission.usersManage,
  WaddlePermission.screensRead,
  WaddlePermission.screensWrite,
  WaddlePermission.integrationsRead,
  WaddlePermission.integrationsWrite,
  WaddlePermission.curatorRead,
  WaddlePermission.curatorWrite,
  WaddlePermission.tickerRead,
  WaddlePermission.tickerWrite,
  WaddlePermission.overlaysRead,
  WaddlePermission.overlaysWrite,
  WaddlePermission.alertsRead,
  WaddlePermission.alertsWrite,
  WaddlePermission.contentModerate,
  WaddlePermission.rejectTermsManage,
  WaddlePermission.navigationControl,
  WaddlePermission.telemetryRead,
  WaddlePermission.metaRead,
};

const _operatorPermissions = <String>{
  WaddlePermission.screensRead,
  WaddlePermission.screensWrite,
  WaddlePermission.integrationsRead,
  WaddlePermission.integrationsWrite,
  WaddlePermission.curatorRead,
  WaddlePermission.curatorWrite,
  WaddlePermission.tickerRead,
  WaddlePermission.tickerWrite,
  WaddlePermission.overlaysRead,
  WaddlePermission.overlaysWrite,
  WaddlePermission.alertsRead,
  WaddlePermission.alertsWrite,
  WaddlePermission.contentModerate,
  WaddlePermission.rejectTermsManage,
  WaddlePermission.navigationControl,
  WaddlePermission.telemetryRead,
  WaddlePermission.metaRead,
};

/// Read-only display program / slide telemetry and related media rows (controller Programs view).
const _viewerPermissions = <String>{
  WaddlePermission.telemetryRead,
};

/// Programs telemetry, remote navigation, and read-only catalog (no suppressed rows or PATCH).
const _powerViewerPermissions = <String>{
  WaddlePermission.telemetryRead,
  WaddlePermission.navigationControl,
  WaddlePermission.contentCatalogRead,
};

const Map<String, Set<String>> kRolePermissions = {
  kUserRoleAdmin: _adminPermissions,
  kUserRoleOperator: _operatorPermissions,
  kUserRolePowerViewer: _powerViewerPermissions,
  kUserRoleViewer: _viewerPermissions,
};

/// All valid role strings.
const Set<String> kValidUserRoles = {
  kUserRoleAdmin,
  kUserRoleOperator,
  kUserRolePowerViewer,
  kUserRoleViewer,
};

List<String> permissionsForRole(String role) {
  final set = kRolePermissions[role];
  if (set == null) {
    return const [];
  }
  final list = set.toList()..sort();
  return list;
}

bool userHasPermission(String role, String permission) {
  return kRolePermissions[role]?.contains(permission) ?? false;
}

bool isValidUserRole(String role) => kValidUserRoles.contains(role);
