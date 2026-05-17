import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../theme/display_theme.dart';
import 'wifi_connection_uri.dart';
import '../../dashboard_viewport_scope.dart';

/// Primary monospaced font used for the guest Wi‑Fi value cells. The display
/// runs on Windows where Consolas is always present; other platforms fall
/// through [kGuestWifiValueMonospaceFontFamilyFallback].
const String kGuestWifiValueMonospaceFontFamily = 'Consolas';

/// Monospaced fall-throughs for the guest Wi‑Fi value cells when the primary
/// [kGuestWifiValueMonospaceFontFamily] isn't installed: Menlo on macOS/iOS,
/// Courier New as the universal Windows/macOS backup, Roboto Mono / generic
/// `monospace` on Android and Linux.
const List<String> kGuestWifiValueMonospaceFontFamilyFallback = <String>[
  'Menlo',
  'Courier New',
  'RobotoMono',
  'monospace',
];

/// Full-slide widget: QR + SSID / security / password from [ParsedWidgetSpec.config]
/// (`connection`: `WIFI:...` string, optional `headline`).
class GuestWifiSlideWidget extends StatelessWidget {
  const GuestWifiSlideWidget({
    super.key,
    required this.spec,
    required this.theme,
  });

  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme.extension<PaletteTertiaryLayers>();
    final iconColor =
        palette?.iconColor ??
        theme.iconTheme.color ??
        theme.colorScheme.onSurfaceVariant;
    final headline = spec.config['headline'] as String? ?? 'Guest WiFi';
    final raw = spec.config['connection'] as String?;
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
            color: iconColor,
          ),
          SizedBox(height: 12 * s),
          Text(
            headline,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 20 * s),
          if (!parsed.isValid) ...[
            Text(
              'Wi‑Fi not configured',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ]
          else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: QrImageView(
                        data: parsed.rawForQr!,
                        size: 220 * s,
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.all(4 * s),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 32 * s),
                SizedBox(
                  width: 420 * s,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _infoRow(theme, s, 'SSID:', parsed.ssid!),
                      _infoRow(theme, s, 'Security:', parsed.securityType!),
                      _infoRow(
                        theme,
                        s,
                        'Password:',
                        parsed.password ?? '—',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
            width: 220 * s,
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: kGuestWifiValueMonospaceFontFamily,
                fontFamilyFallback: kGuestWifiValueMonospaceFontFamilyFallback,
              ),
              textAlign: TextAlign.start,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}
