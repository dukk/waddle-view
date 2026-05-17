import 'package:flutter/material.dart';

import '../../clock.dart';
import '../../extensions/overlay_widget_registry.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/runtime/runtime_signal_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Shows a translucent festive layer above [child]. Priority alerts wrap outside.
class CelebrationOverlayHost extends StatelessWidget {
  const CelebrationOverlayHost({
    super.key,
    required this.db,
    required this.clock,
    required this.dashboardKv,
    required this.allowedOverlayIds,
    required this.overlayRegistry,
    required this.runtimeSignals,
    required this.child,
  });

  final AppDatabase db;
  final Clock clock;
  final Map<String, String> dashboardKv;
  final Set<String> allowedOverlayIds;
  final OverlayWidgetRegistry overlayRegistry;
  final RuntimeSignalRepository runtimeSignals;
  final Widget child;

  static List<String> mergePhrases(List<DisplayOverlayScheduleRow> matches) {
    final seen = <String>{};
    final phrases = <String>[];
    for (final row in matches) {
      for (final m in decodeMessagesNonEmpty(row)) {
        if (seen.add(m)) {
          phrases.add(m);
        }
      }
    }
    return phrases;
  }

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
            builder: (context, overlaySnap) {
              return StreamBuilder<void>(
                stream: runtimeSignals.watchChanges(),
                builder: (context, _) {
                  return FutureBuilder<Map<String, dynamic>>(
                    future: runtimeSignals.snapshot(),
                    builder: (context, signalSnap) {
              final rows = (overlaySnap.data ?? const <DisplayOverlayScheduleRow>[])
                  .where((r) => allowedOverlayIds.contains(r.id))
                  .toList();
              final now = clock.now();
              final cs = Theme.of(context).colorScheme;
              final accents = <Color>[
                cs.secondary,
                cs.tertiary,
                cs.primary,
                cs.outline,
              ];
              final layers = overlayRegistry.buildLayers(
                ctx: CelebrationOverlayBuildContext(
                  theme: Theme.of(context),
                  accents: accents,
                  mergePhrases: mergePhrases,
                ),
                rows: rows,
                now: now,
                runtimeSignals: signalSnap.data ?? const {},
              );
              if (layers.isEmpty) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: layers,
                  ),
                ),
              );
                    },
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
