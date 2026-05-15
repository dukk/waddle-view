import 'package:waddle_shared/persistence/tables.dart';

/// Permission strings exposed to REST clients and enforced on routes.
abstract final class WaddlePermission {
  static const usersManage = 'users.manage';
  static const screensRead = 'screens.read';
  static const screensWrite = 'screens.write';
  static const providersRead = 'providers.read';
  static const providersWrite = 'providers.write';
  static const curatorRead = 'curator.read';
  static const curatorWrite = 'curator.write';
  static const tickerRead = 'ticker.read';
  static const tickerWrite = 'ticker.write';
  static const overlaysRead = 'overlays.read';
  static const overlaysWrite = 'overlays.write';
  static const alertsRead = 'alerts.read';
  static const alertsWrite = 'alerts.write';
  static const contentModerate = 'content.moderate';
  static const rejectTermsManage = 'reject_terms.manage';
  static const navigationControl = 'navigation.control';
  static const telemetryRead = 'telemetry.read';
  static const metaRead = 'meta.read';
}

const _adminPermissions = <String>{
  WaddlePermission.usersManage,
  WaddlePermission.screensRead,
  WaddlePermission.screensWrite,
  WaddlePermission.providersRead,
  WaddlePermission.providersWrite,
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
  WaddlePermission.providersRead,
  WaddlePermission.providersWrite,
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

const _viewerPermissions = <String>{
  WaddlePermission.screensRead,
  WaddlePermission.providersRead,
  WaddlePermission.curatorRead,
  WaddlePermission.tickerRead,
  WaddlePermission.overlaysRead,
  WaddlePermission.alertsRead,
  WaddlePermission.navigationControl,
  WaddlePermission.telemetryRead,
  WaddlePermission.metaRead,
};

const Map<String, Set<String>> kRolePermissions = {
  kUserRoleAdmin: _adminPermissions,
  kUserRoleOperator: _operatorPermissions,
  kUserRoleViewer: _viewerPermissions,
};

/// All valid role strings.
const Set<String> kValidUserRoles = {
  kUserRoleAdmin,
  kUserRoleOperator,
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
