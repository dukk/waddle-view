import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';

/// Generic celebration overlay driven by schedule [config_json] and optional sidecar.
class PluginTemplateOverlay extends StatelessWidget {
  const PluginTemplateOverlay({
    super.key,
    required this.row,
    required this.accents,
  });

  final DisplayOverlayScheduleRow row;
  final List<Color> accents;

  @override
  Widget build(BuildContext context) {
    final config = _parseConfig(row.configJson);
    final opacity = (config['opacity'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.35;
    final messages = _messages(config);
    final color = accents.isNotEmpty ? accents.first : Theme.of(context).colorScheme.primary;

    return IgnorePointer(
      child: Container(
        color: color.withValues(alpha: opacity),
        alignment: Alignment.center,
        child: messages.isEmpty
            ? null
            : Text(
                messages.join(' · '),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      shadows: const [Shadow(blurRadius: 8)],
                    ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  Map<String, dynamic> _parseConfig(String raw) {
    if (raw.trim().isEmpty) {
      return const {};
    }
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) {
        return v;
      }
    } on Object {
      // ignore
    }
    return const {};
  }

  List<String> _messages(Map<String, dynamic> config) {
    final raw = config['messages'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final m in raw)
        if (m.toString().trim().isNotEmpty) m.toString().trim(),
    ];
  }
}
