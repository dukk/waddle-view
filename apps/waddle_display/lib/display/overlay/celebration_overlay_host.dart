import 'package:flutter/material.dart';

import '../../clock.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'birthday_confetti_overlay.dart';
import 'bouncing_message_overlay.dart';
import 'celebration_overlay_schedule.dart';
import 'hearts_rain_overlay.dart';

/// Shows a translucent festive layer above [child]. Priority alerts wrap outside.
class CelebrationOverlayHost extends StatelessWidget {
  const CelebrationOverlayHost({
    super.key,
    required this.db,
    required this.clock,
    required this.dashboardKv,
    required this.allowedOverlayIds,
    required this.child,
  });

  final AppDatabase db;
  final Clock clock;
  final Map<String, String> dashboardKv;

  /// Union of overlay catalog ids from active curator configs; empty hides all.
  final Set<String> allowedOverlayIds;

  final Widget child;

  static List<String> _mergePhrases(List<DisplayOverlayScheduleRow> matches) {
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
            builder: (context, snapshot) {
              final rows = (snapshot.data ?? const <DisplayOverlayScheduleRow>[])
                  .where((r) => allowedOverlayIds.contains(r.id))
                  .toList();
              final now = clock.now();
              final heartMatches =
                  rows
                      .where(
                        (r) =>
                            r.overlayType.trim() == kOverlayTypeHeartsRain &&
                            matchesCelebrationOverlay(r, now),
                      )
                      .toList()
                    ..sort((a, b) => a.id.compareTo(b.id));

              final confettiMatches =
                  rows
                      .where(
                        (r) =>
                            r.overlayType.trim() ==
                                kOverlayTypeBirthdayConfetti &&
                            matchesCelebrationOverlay(r, now),
                      )
                      .toList()
                    ..sort((a, b) => a.id.compareTo(b.id));

              final bouncingMatches =
                  rows
                      .where(
                        (r) =>
                            r.overlayType.trim() ==
                                kOverlayTypeBouncingMessage &&
                            matchesCelebrationOverlay(r, now),
                      )
                      .toList()
                    ..sort((a, b) => a.id.compareTo(b.id));

              if (heartMatches.isEmpty &&
                  confettiMatches.isEmpty &&
                  bouncingMatches.isEmpty) {
                return const SizedBox.shrink();
              }

              final heartPhrases = _mergePhrases(heartMatches);
              final confettiPhrases = _mergePhrases(confettiMatches);
              final bouncePhrases = _mergePhrases(bouncingMatches);

              final cs = Theme.of(context).colorScheme;
              final accents = <Color>[
                cs.secondary,
                cs.tertiary,
                cs.primary,
                cs.outline,
              ];

              final confettiSettings = confettiMatches.isEmpty
                  ? null
                  : BirthdayConfettiScheduleSettings.parse(
                      confettiMatches.first.configJson,
                    );

              final bouncingSettings = bouncingMatches.isEmpty
                  ? null
                  : BouncingMessageScheduleSettings.parse(
                      bouncingMatches.first.configJson,
                    );
              final bouncingText = bouncePhrases.isEmpty
                  ? kDefaultBouncingMessageOverlayPhrase
                  : bouncePhrases.first;

              return Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (confettiSettings != null)
                        BirthdayConfettiOverlay(
                          settings: confettiSettings,
                          messages: confettiPhrases,
                          fallbackAccents: accents,
                        ),
                      if (heartMatches.isNotEmpty)
                        HeartsRainOverlay(
                          messages: heartPhrases.isEmpty
                              ? const ['']
                              : heartPhrases,
                          fallbackAccents: accents,
                        ),
                      if (bouncingSettings != null)
                        BouncingMessageOverlay(
                          settings: bouncingSettings,
                          text: bouncingText,
                          fallbackColor: cs.primary,
                        ),
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
