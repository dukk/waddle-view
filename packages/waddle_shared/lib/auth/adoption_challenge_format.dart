import '../persistence/tables.dart';

/// Crockford challenge without separators (8 characters).
String normalizeAdoptionChallengeCode(String input) {
  final buffer = StringBuffer();
  for (final unit in input.toUpperCase().codeUnits) {
    final ch = String.fromCharCode(unit);
    if (_isChallengeChar(ch)) {
      buffer.write(ch);
    }
    if (buffer.length >= 8) {
      break;
    }
  }
  return buffer.toString();
}

/// Display form `XXXX-XXXX` for an 8-character challenge.
String formatAdoptionChallengeCode(String rawCode) {
  final normalized = normalizeAdoptionChallengeCode(rawCode);
  if (normalized.length <= 4) {
    return normalized;
  }
  return '${normalized.substring(0, 4)}-${normalized.substring(4)}';
}

bool _isChallengeChar(String ch) {
  if (ch.length != 1) {
    return false;
  }
  final c = ch.codeUnitAt(0);
  return (c >= 48 && c <= 57) || (c >= 65 && c <= 90);
}

/// Human-readable role label for kiosk adoption alerts.
String adoptionRoleDisplayLabel(String role) {
  switch (role) {
    case kUserRoleAdmin:
      return 'Admin';
    case kUserRoleOperator:
      return 'Operator';
    case kUserRolePowerViewer:
      return 'Power viewer';
    case kUserRoleViewer:
      return 'Viewer';
    default:
      return role;
  }
}
