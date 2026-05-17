import 'dart:convert';

import '../auth/role_permissions.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'adoption.dart';

/// Display order for adoption role pickers (least to most privileged).
const List<String> kAdoptionConfigurableRoles = [
  kUserRoleViewer,
  kUserRolePowerViewer,
  kUserRoleOperator,
  kUserRoleAdmin,
];

/// Roles that may start adoption challenges (default: all valid roles).
Future<Set<String>> readAdoptionAllowedRoles(AppDatabase db) async {
  final rolesRow = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kAdoptionAllowedRolesKvKey)))
      .getSingleOrNull();
  if (rolesRow != null) {
    return _parseAdoptionAllowedRolesValue(rolesRow.value);
  }

  final legacyRow = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kAdoptionAllowNewRequestsKvKey)))
      .getSingleOrNull();
  if (legacyRow != null && legacyRow.value.trim().toLowerCase() == 'false') {
    return {};
  }

  return Set<String>.from(kValidUserRoles);
}

/// Whether [role] may start a public adoption challenge.
Future<bool> isAdoptionRoleAllowed(AppDatabase db, String role) async {
  final allowed = await readAdoptionAllowedRoles(db);
  return allowed.contains(role);
}

Set<String> _parseAdoptionAllowedRolesValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return {};
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return decoded
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => isValidUserRole(s))
          .toSet();
    }
  } catch (_) {
    /* fall through to comma-separated */
  }
  return trimmed
      .split(RegExp(r'[,\s]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && isValidUserRole(s))
      .toSet();
}

/// Canonical JSON array for [kAdoptionAllowedRolesKvKey].
String encodeAdoptionAllowedRoles(Set<String> roles) {
  final sorted = roles.where(isValidUserRole).toList()
    ..sort((a, b) {
      final ai = kAdoptionConfigurableRoles.indexOf(a);
      final bi = kAdoptionConfigurableRoles.indexOf(b);
      return (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
    });
  return jsonEncode(sorted);
}
