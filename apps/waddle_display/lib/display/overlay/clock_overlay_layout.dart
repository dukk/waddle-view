import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';

/// Stacks one or more positioned overlay children using normalized anchors.
class ClockOverlayLayout extends StatelessWidget {
  const ClockOverlayLayout({
    super.key,
    required this.placements,
    required this.childBuilder,
  });

  final List<ClockOverlayPlacement> placements;
  final Widget Function(
    BuildContext context,
    int index,
    ClockOverlayPlacement placement,
    double blockWidth,
  ) childBuilder;

  @override
  Widget build(BuildContext context) {
    if (placements.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }
        final shortest = width < height ? width : height;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < placements.length; i++)
              _positionedChild(
                placement: placements[i],
                viewportWidth: width,
                viewportHeight: height,
                blockWidth: placements[i].scale * shortest,
                child: childBuilder(
                  context,
                  i,
                  placements[i],
                  placements[i].scale * shortest,
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget _positionedChild({
  required ClockOverlayPlacement placement,
  required double viewportWidth,
  required double viewportHeight,
  required double blockWidth,
  required Widget child,
}) {
  final left = placement.x * viewportWidth;
  final top = placement.y * viewportHeight;
  Widget content = SizedBox(width: blockWidth, child: child);
  if (placement.opacity < 1.0) {
    content = Opacity(opacity: placement.opacity, child: content);
  }
  return Positioned(
    left: left,
    top: top,
    width: blockWidth,
    child: content,
  );
}
