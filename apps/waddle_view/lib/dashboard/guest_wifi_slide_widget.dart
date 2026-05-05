import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../curator/screen_layout_parse.dart';
import '../persistence/database.dart';
import 'wifi_connection_uri.dart';

/// Full-slide widget: QR + SSID / security / password from [dashboard_kv].
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

    return StreamBuilder<DashboardKvData?>(
      stream: (db.select(db.dashboardKv)..where((t) => t.key.equals(kvKey)))
          .watchSingleOrNull(),
      builder: (context, snapshot) {
        final raw = snapshot.data?.value;
        final parsed = parseWifiConnectionUri(raw);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                headline,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _infoRow(theme, 'SSID', parsed.ssid!),
                _infoRow(theme, 'Security', parsed.securityType!),
                _infoRow(
                  theme,
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

  static Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 12),
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
