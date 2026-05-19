import 'package:flutter/material.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_floating_balloons_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_row.dart';
import 'package:waddle_shared/persistence/display_overlay_edge_glow_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_matrix_rain_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_shape_rain_settings.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../display/overlay/birthday_confetti_overlay.dart';
import '../display/overlay/bouncing_message_overlay.dart';
import '../display/overlay/celebration_overlay_schedule.dart';
import '../display/overlay/falling_images_overlay.dart';
import '../display/overlay/floating_balloons_overlay.dart';
import '../display/overlay/edge_glow_overlay.dart';
import '../display/overlay/matrix_rain_overlay.dart';
import '../display/overlay/shape_rain_overlay.dart';
import '../display/overlay/plugin_template_overlay.dart';
import '../display/overlay/plugin_web_overlay.dart';

typedef CelebrationOverlayLayerBuilder = Widget? Function(
  CelebrationOverlayBuildContext ctx,
  List<DisplayOverlayRow> matches,
);

class CelebrationOverlayBuildContext {
  const CelebrationOverlayBuildContext({
    required this.theme,
    required this.accents,
    required this.mergePhrases,
    required this.blobs,
    required this.db,
  });

  final ThemeData theme;
  final List<Color> accents;
  final List<String> Function(List<DisplayOverlayRow>) mergePhrases;
  final BlobStore blobs;
  final AppDatabase db;
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
    required List<DisplayOverlayRow> rows,
    required DateTime now,
    Map<String, dynamic> runtimeSignals = const {},
  }) {
    final byType = <String, List<DisplayOverlayRow>>{};
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
        layers.add(
          KeyedSubtree(
            key: ValueKey(_overlayLayerIdentity(entry.key, entry.value)),
            child: w,
          ),
        );
      }
    }
    return layers;
  }
}

/// Stable identity for overlay layer state when rows or `config_json` change.
String _overlayLayerIdentity(String overlayType, List<DisplayOverlayRow> rows) {
  final parts = rows.map((r) => '${r.id}\u0000${r.configJson}').join('\u0001');
  return '$overlayType\u0002$parts';
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
      fallbackAccents: ctx.accents,
    );
  });

  void registerShapeRain(CelebrationOverlayLayerBuilder builder) {
    registry.register(kOverlayTypeShapeRain, builder);
    registry.register(kOverlayTypeHeartsRain, builder);
  }

  registerShapeRain((ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final settings = ShapeRainScheduleSettings.parse(matches.first.configJson);
    return ShapeRainOverlay(
      settings: settings,
      fallbackAccents: ctx.accents,
    );
  });

  registry.register(kOverlayTypeMatrixRain, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final settings = MatrixRainScheduleSettings.parse(matches.first.configJson);
    return MatrixRainOverlay(settings: settings);
  });

  registry.register(kOverlayTypeEdgeGlow, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final settings = EdgeGlowScheduleSettings.parse(matches.first.configJson);
    return EdgeGlowOverlay(settings: settings);
  });

  registry.register(kOverlayTypeFallingImages, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final settings = FallingImagesScheduleSettings.parse(
      matches.first.configJson,
    );
    if (settings.imageBlobKeys.isEmpty) {
      return null;
    }
    return FallingImagesOverlay(
      settings: settings,
      blobs: ctx.blobs,
      db: ctx.db,
    );
  });

  registry.register(kOverlayTypeFloatingBalloons, (ctx, matches) {
    if (matches.isEmpty) {
      return null;
    }
    final settings = FloatingBalloonsScheduleSettings.parse(
      matches.first.configJson,
    );
    if (settings.effectiveColorHexes.isEmpty) {
      return null;
    }
    return FloatingBalloonsOverlay(settings: settings);
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
