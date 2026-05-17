import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../display/overlay/birthday_confetti_overlay.dart';
import '../display/overlay/bouncing_message_overlay.dart';
import '../display/overlay/celebration_overlay_schedule.dart';
import '../display/overlay/hearts_rain_overlay.dart';
import '../display/overlay/plugin_template_overlay.dart';
import '../display/overlay/plugin_web_overlay.dart';

typedef CelebrationOverlayLayerBuilder = Widget? Function(
  CelebrationOverlayBuildContext ctx,
  List<DisplayOverlayScheduleRow> matches,
);

class CelebrationOverlayBuildContext {
  const CelebrationOverlayBuildContext({
    required this.theme,
    required this.accents,
    required this.mergePhrases,
  });

  final ThemeData theme;
  final List<Color> accents;
  final List<String> Function(List<DisplayOverlayScheduleRow>) mergePhrases;
}

class OverlayWidgetRegistry {
  OverlayWidgetRegistry() {
    registerBuiltins(this);
  }

  final Map<String, CelebrationOverlayLayerBuilder> _builders = {};

  void register(String overlayType, CelebrationOverlayLayerBuilder builder) {
    _builders[overlayType.trim()] = builder;
  }

  CelebrationOverlayLayerBuilder? lookup(String overlayType) =>
      _builders[overlayType.trim()];

  List<Widget> buildLayers({
    required CelebrationOverlayBuildContext ctx,
    required List<DisplayOverlayScheduleRow> rows,
    required DateTime now,
    Map<String, dynamic> runtimeSignals = const {},
  }) {
    final byType = <String, List<DisplayOverlayScheduleRow>>{};
    for (final row in rows) {
      if (!matchesCelebrationOverlay(row, now, runtimeSignals: runtimeSignals)) {
        continue;
      }
      final t = row.overlayType.trim();
      byType.putIfAbsent(t, () => []).add(row);
    }
    final layers = <Widget>[];
    for (final entry in byType.entries) {
      entry.value.sort((a, b) => a.id.compareTo(b.id));
      final builder = _builders[entry.key];
      if (builder == null) {
        continue;
      }
      final w = builder(ctx, entry.value);
      if (w != null) {
        layers.add(w);
      }
    }
    return layers;
  }
}

void registerBuiltins(OverlayWidgetRegistry registry) {
  registry.register(kOverlayTypeBirthdayConfetti, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final settings = BirthdayConfettiScheduleSettings.parse(
      matches.first.configJson,
    );
    return BirthdayConfettiOverlay(
      settings: settings,
      messages: ctx.mergePhrases(matches),
      fallbackAccents: ctx.accents,
    );
  });

  registry.register(kOverlayTypeHeartsRain, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final phrases = ctx.mergePhrases(matches);
    return HeartsRainOverlay(
      messages: phrases.isEmpty ? const [''] : phrases,
      fallbackAccents: ctx.accents,
    );
  });

  registry.register(kOverlayTypeBouncingMessage, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final settings = BouncingMessageScheduleSettings.parse(
      matches.first.configJson,
    );
    final phrases = ctx.mergePhrases(matches);
    final text = phrases.isEmpty
        ? kDefaultBouncingMessageOverlayPhrase
        : phrases.first;
    return BouncingMessageOverlay(
      settings: settings,
      text: text,
      fallbackColor: ctx.theme.colorScheme.primary,
    );
  });

  registry.register(kOverlayRendererPluginTemplate, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    return PluginTemplateOverlay(
      row: matches.first,
      accents: ctx.accents,
    );
  });

  registry.register(kOverlayRendererPluginWeb, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    return PluginWebOverlay(row: matches.first);
  });
}
