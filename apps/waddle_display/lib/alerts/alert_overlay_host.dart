import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../clock.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'alert_overlay_dialog.dart';
import 'alert_repository.dart';
import 'alert_severity_icons_kv.dart';

/// Dimmed overlay for the highest-priority active alert.
class AlertOverlayHost extends StatelessWidget {
  const AlertOverlayHost({
    super.key,
    required this.repository,
    required this.clock,
    required this.child,
    this.severityIconsKv,
  });

  final AlertRepository repository;
  final Clock clock;
  final Widget child;

  /// Raw JSON from [kAlertSeverityIconsKvKey] in [config_key_values]; merged with defaults.
  final String? severityIconsKv;

  @override
  Widget build(BuildContext context) {
    final severityIconNames = parseAlertSeverityIconsKv(severityIconsKv);
    return StreamBuilder<DashboardAlert?>(
      stream: repository.watchActive(clock),
      builder: (context, snap) {
        final alert = snap.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (alert != null)
              Positioned.fill(
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                      unawaited(repository.dismiss(alert.id));
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Material(
                    color: Colors.black54,
                    child: Center(
                      child: AlertOverlayDialog(
                        alert: alert,
                        clock: clock,
                        severityIconNames: severityIconNames,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
