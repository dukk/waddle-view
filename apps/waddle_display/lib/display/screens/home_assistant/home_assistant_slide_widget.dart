import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../dashboard_viewport_scope.dart';

/// Renders the latest [HomeAssistantEntityStates] for enabled interest rows.
class HomeAssistantSlideWidget extends StatelessWidget {
  const HomeAssistantSlideWidget({
    super.key,
    required this.db,
    required this.slide,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final entitiesQuery = db.select(db.interestsHomeAssistantEntities)
      ..where((t) => t.enabled.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.entityId)]);
    return StreamBuilder<List<InterestsHomeAssistantEntity>>(
      stream: entitiesQuery.watch(),
      builder: (context, entitiesSnap) {
        final entities =
            entitiesSnap.data ?? const <InterestsHomeAssistantEntity>[];
        if (entities.isEmpty) {
          return _empty('No Home Assistant entities configured');
        }
        return StreamBuilder<List<HomeAssistantEntityState>>(
          stream: db.select(db.homeAssistantEntityStates).watch(),
          builder: (context, statesSnap) {
            final states = statesSnap.data ?? const <HomeAssistantEntityState>[];
            final byEntityId = {for (final s in states) s.entityId: s};
            final s = DashboardViewportScope.scaleOf(context);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24 * s,
                vertical: 16 * s,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Home Assistant', style: theme.textTheme.headlineSmall),
                  SizedBox(height: 18 * s),
                  Wrap(
                    spacing: 24 * s,
                    runSpacing: 16 * s,
                    alignment: WrapAlignment.center,
                    children: entities
                        .map((entity) => _entityTile(
                              entity: entity,
                              state: byEntityId[entity.entityId],
                              scale: s,
                            ))
                        .toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _entityTile({
    required InterestsHomeAssistantEntity entity,
    required HomeAssistantEntityState? state,
    required double scale,
  }) {
    final attributes = _parseAttributes(state?.attributesJson);
    final label = entity.displayName.trim().isNotEmpty
        ? entity.displayName.trim()
        : (attributes['friendly_name'] as String?)?.trim().isNotEmpty == true
            ? (attributes['friendly_name'] as String).trim()
            : entity.entityId;
    final unit = (attributes['unit_of_measurement'] as String?)?.trim();
    final stateText = state != null
        ? (unit != null && unit.isNotEmpty
            ? '${state.state} $unit'
            : state.state)
        : '—';
    return SizedBox(
      width: 280 * scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 12 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (entity.displayName.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2 * scale),
                  child: Text(
                    entity.entityId,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(height: 8 * scale),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  stateText,
                  style: theme.textTheme.headlineSmall,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseAttributes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on Object {
      // ignore
    }
    return const {};
  }

  Widget _empty(String text) {
    return Builder(
      builder: (context) {
        final s = DashboardViewportScope.scaleOf(context);
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Text(
            text,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
