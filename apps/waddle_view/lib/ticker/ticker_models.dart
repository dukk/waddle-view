import 'package:meta/meta.dart';

import '../persistence/database.dart';

@immutable
class TickerConditionGroupBundle {
  const TickerConditionGroupBundle({
    required this.group,
    required this.conditions,
  });

  final TickerConditionGroup group;
  final List<TickerCondition> conditions;
}

@immutable
class TickerScreenBundle {
  const TickerScreenBundle({
    required this.screen,
    required this.groups,
    this.runtime,
  });

  final TickerScreen screen;
  final List<TickerConditionGroupBundle> groups;
  final TickerScreenRuntime? runtime;
}
