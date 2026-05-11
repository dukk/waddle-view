import 'package:flutter/material.dart';

import '../../clock.dart';
import '../../persistence/database.dart';
import '../../persistence/display_overlay_repository.dart';
import '../../persistence/display_overlay_schedule_row.dart';
import '../../persistence/tables.dart';
import 'celebration_overlay_schedule.dart';
import 'hearts_rain_overlay.dart';

/// Shows a translucent festive layer above [child]. Priority alerts wrap outside.
class CelebrationOverlayHost extends StatelessWidget {
  const CelebrationOverlayHost({
    super.key,
    required this.db,
    required this.clock,
    required this.dashboardKv,
    required this.child,
  });

  final AppDatabase db;
  final Clock clock;
  final Map<String, String> dashboardKv;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final globalOk = parseDisplayOverlayGloballyEnabled(
      dashboardKv[kDisplayOverlayEnabledKvKey],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (globalOk)
          StreamBuilder<List<DisplayOverlayScheduleRow>>(
            stream: watchDisplayOverlaySchedules(db),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <DisplayOverlayScheduleRow>[];
              final now = clock.now();
              final matches = rows
                      .where(
                        (r) =>
                            r.overlayKind.trim() == kOverlayKindHeartsRain &&
                            matchesCelebrationOverlay(r, now),
                      )
                      .toList()
                    ..sort((a, b) => a.id.compareTo(b.id));
              if (matches.isEmpty) {
                return const SizedBox.shrink();
              }
              final seen = <String>{};
              final phrases = <String>[];
              for (final row in matches) {
                for (final m in decodeMessagesNonEmpty(row)) {
                  if (seen.add(m)) {
                    phrases.add(m);
                  }
                }
              }
              final cs = Theme.of(context).colorScheme;
              return Positioned.fill(
                child: IgnorePointer(
                  child: HeartsRainOverlay(
                    messages: phrases.isEmpty ? const [''] : phrases,
                    fallbackAccents: <Color>[
                      cs.secondary,
                      cs.tertiary,
                      cs.primary,
                      cs.outline,
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
