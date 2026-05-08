import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../clock.dart';
import '../display/dashboard_viewport_scope.dart';
import '../persistence/database.dart';
import 'alert_material_icon.dart';

/// Semi-transparent “window” card for a single active alert (title bar, body, optional QR).
class AlertOverlayDialog extends StatefulWidget {
  const AlertOverlayDialog({
    super.key,
    required this.alert,
    required this.clock,
    required this.severityIconNames,
  });

  final DashboardAlert alert;
  final Clock clock;
  final Map<String, String> severityIconNames;

  @override
  State<AlertOverlayDialog> createState() => _AlertOverlayDialogState();
}

class _AlertOverlayDialogState extends State<AlertOverlayDialog> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _maybeStartTicker();
  }

  @override
  void didUpdateWidget(AlertOverlayDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alert.id != widget.alert.id ||
        oldWidget.alert.expiresAt != widget.alert.expiresAt) {
      _tick?.cancel();
      _maybeStartTicker();
    }
  }

  void _maybeStartTicker() {
    if (widget.alert.expiresAt == null) {
      return;
    }
    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  double? _expiryRemainingFraction() {
    final end = widget.alert.expiresAt;
    if (end == null) {
      return null;
    }
    final start = widget.alert.createdAt;
    final totalMs = end.difference(start).inMilliseconds;
    if (totalMs <= 0) {
      return null;
    }
    final now = widget.clock.now();
    final remainingMs = end.difference(now).inMilliseconds;
    if (remainingMs <= 0) {
      return 0;
    }
    return (remainingMs / totalMs).clamp(0.0, 1.0);
  }

  Widget _buildExpiryProgressBar(ThemeData theme, double s) {
    final remaining = _expiryRemainingFraction();
    if (remaining == null) {
      return const SizedBox.shrink();
    }
    final h = 7 * s;
    final trackColor =
        theme.colorScheme.secondaryContainer.withValues(alpha: 0.55);
    final fillColor = theme.colorScheme.secondary.withValues(alpha: 0.5);
    return Padding(
      padding: EdgeInsets.only(top: 16 * s, left: 16 * s, right: 16 * s),
      child: Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: SizedBox(
            key: const ValueKey<String>('alert_expiry_progress'),
            height: h,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(4 * s),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: remaining,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(4 * s),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = DashboardViewportScope.scaleOf(context);
    final alert = widget.alert;
    final hasQr = (alert.qrPayload ?? '').isNotEmpty;
    final icon = resolveAlertSeverityIcon(alert.severity, widget.severityIconNames);

    final cardFill = scheme.surface.withValues(alpha: 0.88);
    final headerFill = scheme.surfaceContainerHigh.withValues(alpha: 0.92);
    final borderColor = scheme.surfaceContainerHigh.withValues(alpha: 0.95);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 10,
        color: cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
              decoration: BoxDecoration(
                color: headerFill,
                border: Border(
                  bottom: BorderSide(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 26 * s, color: scheme.onPrimaryFixedVariant),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Text(
                      alert.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16 * s),
              child: hasQr
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              alert.body,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                        SizedBox(width: 20 * s),
                        QrImageView(
                          data: alert.qrPayload!,
                          size: 180 * s,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.all(4 * s),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Text(
                        alert.body,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
            ),
            _buildExpiryProgressBar(theme, s),
            SizedBox(height: 8 * s),
          ],
        ),
      ),
    );
  }
}
