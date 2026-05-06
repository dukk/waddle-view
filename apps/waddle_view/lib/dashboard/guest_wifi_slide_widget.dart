import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../curator/screen_layout_parse.dart';
import '../persistence/database.dart';
import 'wifi_connection_uri.dart';
import 'dashboard_viewport_scope.dart';

/// Full-slide widget: QR + SSID / security / password from [config_key_values].
class GuestWifiSlideWidget extends StatelessWidget {
  const GuestWifiSlideWidget({
    super.key,
    required this.db,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final kvKey = spec.config['kvKey'] as String? ?? kGuestWifiDashboardKvKey;
    final headline = spec.config['headline'] as String? ?? 'Guest WiFi';

    return StreamBuilder<ConfigKeyValue?>(
      stream: (db.select(db.configKeyValues)..where((t) => t.key.equals(kvKey)))
          .watchSingleOrNull(),
      builder: (context, snapshot) {
        final raw = snapshot.data?.value;
        final parsed = parseWifiConnectionUri(raw);
        final s = DashboardViewportScope.scaleOf(context);

        return Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi,
                size: 112 * s,
                color: theme.colorScheme.primary,
              ),
              SizedBox(height: 12 * s),
              Text(
                headline,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20 * s),
              if (!parsed.isValid)
                Text(
                  'Guest Wi‑Fi not configured',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                )
              else ...[
                Center(
                  child: QrImageView(
                    data: parsed.rawForQr!,
                    size: 220 * s,
                    backgroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 20 * s),
                _infoRow(theme, s, 'SSID', parsed.ssid!),
                _infoRow(theme, s, 'Security', parsed.securityType!),
                _infoRow(
                  theme,
                  s,
                  'Password',
                  parsed.password ?? '—',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _infoRow(ThemeData theme, double s, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120 * s,
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(width: 12 * s),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}
