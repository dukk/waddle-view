import 'curator_member_op.dart';
import 'curator_schedule_resolver.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Resolves the final active catalog ids for [entityType] from layered curator ops.
Set<String> resolveEffectiveMemberIds({
  required ResolvedCuratorSelection selection,
  required Map<String, CuratorConfigurationInput> configById,
  required String entityType,
}) {
  final contributors = _contributingConfigurations(
    selection: selection,
    configById: configById,
  );
  contributors.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  final present = <String, bool>{};
  for (final config in contributors) {
    final ops = _opsForEntityType(config, entityType);
    for (final op in ops) {
      present[op.entityId] = op.isAdd;
    }
  }
  return present.entries.where((e) => e.value).map((e) => e.key).toSet();
}

List<CuratorConfigurationInput> _contributingConfigurations({
  required ResolvedCuratorSelection selection,
  required Map<String, CuratorConfigurationInput> configById,
}) {
  if (selection.exclusive != null) {
    return [selection.exclusive!.configuration];
  }

  final out = <CuratorConfigurationInput>[];
  final base = selection.base?.configuration;
  if (base != null) {
    out.addAll(_ancestorChain(base, configById));
    out.add(base);
  }
  for (final e in selection.enhancements) {
    out.add(e.configuration);
  }
  return out;
}

List<CuratorConfigurationInput> _ancestorChain(
  CuratorConfigurationInput config,
  Map<String, CuratorConfigurationInput> configById,
) {
  final ancestors = <CuratorConfigurationInput>[];
  final visited = <String>{};
  var parentId = config.parentConfigurationId;
  while (parentId != null && parentId.isNotEmpty) {
    if (!visited.add(parentId)) {
      throw StateError(
        'Curator configuration parent cycle detected at $parentId',
      );
    }
    final parent = configById[parentId];
    if (parent == null) {
      break;
    }
    ancestors.add(parent);
    parentId = parent.parentConfigurationId;
  }
  return ancestors.reversed.toList();
}

List<CuratorMemberOp> _opsForEntityType(
  CuratorConfigurationInput config,
  String entityType,
) {
  switch (entityType) {
    case kCuratorMemberEntityScreen:
      return config.screenMemberOps;
    case kCuratorMemberEntityTicker:
      return config.tickerMemberOps;
    case kCuratorMemberEntityOverlay:
      return config.overlayMemberOps;
    default:
      return const [];
  }
}
