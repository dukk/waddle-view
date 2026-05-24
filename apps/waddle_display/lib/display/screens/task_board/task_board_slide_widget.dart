import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:flutter/material.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../../theme/display_theme.dart';
import '../../dashboard_viewport_scope.dart';

int _cfgInt(Map<String, dynamic> c, String key, int def) {
  final v = c[key];
  if (v is int) return v;
  if (v is double) return v.round();
  return def;
}

bool _cfgBool(Map<String, dynamic> c, String key, bool def) {
  final v = c[key];
  if (v is bool) return v;
  return def;
}

/// Horizontal kanban columns for one [boardKey] from synced task_lists / tasks.
class TaskBoardSlideWidget extends StatelessWidget {
  const TaskBoardSlideWidget({
    super.key,
    required this.db,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final boardKey = (spec.config['boardKey'] as String?)?.trim() ?? '';
    if (boardKey.isEmpty) {
      return Center(
        child: Text(
          'Task board: set boardKey in screen config',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }
    final maxPerColumn = _cfgInt(
      spec.config,
      'maxTasksPerColumn',
      12,
    ).clamp(1, 50);
    final showCompleted = _cfgBool(spec.config, 'showCompleted', false);
    final s = DashboardViewportScope.scaleOf(context);

    final listsQuery = db.select(db.taskLists)
      ..where((t) => t.boardKey.equals(boardKey))
      ..orderBy([(t) => OrderingTerm.asc(t.columnOrder)]);

    return StreamBuilder<List<TaskList>>(
      stream: listsQuery.watch(),
      builder: (context, listsSnap) {
        final lists = listsSnap.data ?? const <TaskList>[];
        if (lists.isEmpty) {
          return Center(
            child: Text(
              'No task lists for board $boardKey',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 16 * s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final list in lists)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * s),
                    child: _TaskColumn(
                      db: db,
                      list: list,
                      theme: theme,
                      scale: s,
                      maxTasks: maxPerColumn,
                      showCompleted: showCompleted,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskColumn extends StatelessWidget {
  const _TaskColumn({
    required this.db,
    required this.list,
    required this.theme,
    required this.scale,
    required this.maxTasks,
    required this.showCompleted,
  });

  final AppDatabase db;
  final TaskList list;
  final ThemeData theme;
  final double scale;
  final int maxTasks;
  final bool showCompleted;

  @override
  Widget build(BuildContext context) {
    final tasksQuery = db.select(db.tasks)
      ..where((t) {
        Expression<bool> pred = t.taskListId.equals(list.id);
        if (!showCompleted) {
          pred = pred & t.completed.equals(false);
        }
        return pred;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.position)])
      ..limit(maxTasks);

    return StreamBuilder<List<Task>>(
      stream: tasksQuery.watch(),
      builder: (context, tasksSnap) {
        final tasks = tasksSnap.data ?? const <Task>[];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.slidePanelColor,
            borderRadius: BorderRadius.circular(12 * scale),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12 * scale,
                  12 * scale,
                  12 * scale,
                  8 * scale,
                ),
                child: Text(
                  list.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          10 * scale,
                          0,
                          10 * scale,
                          12 * scale,
                        ),
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => SizedBox(height: 8 * scale),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _TaskCard(
                            task: task,
                            theme: theme,
                            scale: scale,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.theme,
    required this.scale,
  });

  final Task task;
  final ThemeData theme;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final due = task.dueAtMs;
    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (due != null) ...[
            SizedBox(height: 4 * scale),
            Text(
              _formatDue(due),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDue(DateTime due) {
    final local = due.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return 'Due $y-$m-$d';
  }
}
