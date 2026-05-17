import 'package:flutter/material.dart';

import '../display/content_category_material_icon.dart';
import 'alert_severity_icons_kv.dart';

/// Resolves Material icon names (e.g. from [kAlertSeverityIconsKvKey]) to [IconData].
IconData alertMaterialIconFromName(String name) {
  switch (name) {
    case 'info_outline':
      return Icons.info_outline;
    case 'lock_outline':
      return Icons.lock_outline;
    case 'security':
      return Icons.security;
    case 'warning_amber_rounded':
      return Icons.warning_amber_rounded;
    case 'error_outline':
      return Icons.error_outline;
    case 'report_problem_outlined':
      return Icons.report_problem_outlined;
    case 'notifications_active_outlined':
      return Icons.notifications_active_outlined;
    case 'help_outline':
      return Icons.help_outline;
    case 'campaign_outlined':
      return Icons.campaign_outlined;
    default:
      return contentCategoryMaterialIcon(name);
  }
}

IconData resolveAlertSeverityIcon(String severity, Map<String, String> cfg) {
  final key = severity.trim().toLowerCase();
  final name =
      cfg[key] ?? kDefaultAlertSeverityMaterialNames[key] ?? 'info_outline';
  return alertMaterialIconFromName(name);
}
