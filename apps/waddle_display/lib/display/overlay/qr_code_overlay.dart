import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:waddle_shared/persistence/display_overlay_qr_code_settings.dart';

import '../dashboard_viewport_scope.dart';
import 'clock_overlay_layout.dart';

/// Renders one or more positioned QR codes with optional title/description.
class QrCodeOverlay extends StatelessWidget {
  const QrCodeOverlay({
    super.key,
    required this.settingsList,
    required this.theme,
  });

  final List<QrCodeOverlaySettings> settingsList;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final renderable =
        settingsList.where((s) => s.isRenderable).toList(growable: false);
    if (renderable.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClockOverlayLayout(
      placements: renderable.map((s) => s.placement).toList(),
      childBuilder: (context, index, placement, blockWidth) {
        final settings = renderable[index];
        return _QrCodeOverlayBlock(
          settings: settings,
          theme: theme,
          blockWidth: blockWidth,
        );
      },
    );
  }
}

class _QrCodeOverlayBlock extends StatelessWidget {
  const _QrCodeOverlayBlock({
    required this.settings,
    required this.theme,
    required this.blockWidth,
  });

  final QrCodeOverlaySettings settings;
  final ThemeData theme;
  final double blockWidth;

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    final qrSize = blockWidth * 0.85;
    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontSize: (theme.textTheme.headlineSmall?.fontSize ?? 24) * s,
    );
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * s,
    );

    final children = <Widget>[];
    if (settings.title.isNotEmpty) {
      children.add(
        Text(
          settings.title,
          style: titleStyle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
      children.add(SizedBox(height: 6 * s));
    }
    children.add(
      Center(
        child: QrImageView(
          data: settings.payload,
          size: qrSize,
          backgroundColor: Colors.white,
          padding: EdgeInsets.all(4 * s),
        ),
      ),
    );
    if (settings.description.isNotEmpty) {
      children.add(SizedBox(height: 6 * s));
      children.add(
        Text(
          settings.description,
          style: bodyStyle,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
