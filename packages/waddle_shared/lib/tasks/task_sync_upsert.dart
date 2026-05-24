import 'package:drift/drift.dart';

import '../persistence/database.dart';

/// Stable Waddle id for a synced task list row.
String taskListIdFor({
  required String integrationType,
  required String integrationId,
  required String externalListId,
}) {
  final safeType = integrationType.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final safeIntegration = integrationId.replaceAll(
    RegExp(r'[^a-zA-Z0-9_]'),
    '_',
  );
  final safeExternal = externalListId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  return '${safeType}_${safeIntegration}_list_$safeExternal';
}

/// Stable Waddle id for a synced task row.
String taskIdFor({
  required String integrationType,
  required String integrationId,
  required String externalTaskId,
}) {
  final safeType = integrationType.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  final safeIntegration = integrationId.replaceAll(
    RegExp(r'[^a-zA-Z0-9_]'),
    '_',
  );
  final safeExternal = externalTaskId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  return '${safeType}_${safeIntegration}_task_$safeExternal';
}

/// One list column and its tasks from an external board snapshot.
class TaskListSnapshot {
  const TaskListSnapshot({
    required this.externalId,
    required this.label,
    required this.columnOrder,
    required this.tasks,
  });

  final String externalId;
  final String label;
  final int columnOrder;
  final List<TaskSnapshot> tasks;
}

/// One task card from an external list.
class TaskSnapshot {
  const TaskSnapshot({
    required this.externalId,
    required this.title,
    this.description,
    this.dueAtMs,
    required this.completed,
    required this.position,
  });

  final String externalId;
  final String title;
  final String? description;
  final DateTime? dueAtMs;
  final bool completed;
  final int position;
}

/// Upserts lists and tasks for one board, then deletes stale rows for that board.
Future<void> syncTaskBoardSnapshot(
  AppDatabase db, {
  required String integrationType,
  required String integrationId,
  required String boardKey,
  required List<TaskListSnapshot> lists,
  required DateTime updatedAt,
}) async {
  final seenListExternalIds = <String>{};
  for (final list in lists) {
    final listExternal = list.externalId.trim();
    if (listExternal.isEmpty) {
      continue;
    }
    seenListExternalIds.add(listExternal);
    final listId = taskListIdFor(
      integrationType: integrationType,
      integrationId: integrationId,
      externalListId: listExternal,
    );
    await db
        .into(db.taskLists)
        .insertOnConflictUpdate(
          TaskListsCompanion.insert(
            id: listId,
            label: list.label.trim().isEmpty ? 'Column' : list.label.trim(),
            boardKey: boardKey,
            columnOrder: list.columnOrder,
            integrationType: integrationType,
            integrationId: integrationId,
            externalId: listExternal,
            updatedAtMs: updatedAt,
          ),
        );

    final seenTaskExternalIds = <String>{};
    for (final task in list.tasks) {
      final taskExternal = task.externalId.trim();
      if (taskExternal.isEmpty) {
        continue;
      }
      seenTaskExternalIds.add(taskExternal);
      final taskId = taskIdFor(
        integrationType: integrationType,
        integrationId: integrationId,
        externalTaskId: taskExternal,
      );
      await db
          .into(db.tasks)
          .insertOnConflictUpdate(
            TasksCompanion.insert(
              id: taskId,
              taskListId: listId,
              title: task.title.trim().isEmpty
                  ? '(Untitled)'
                  : task.title.trim(),
              description: Value(task.description?.trim()),
              dueAtMs: Value(task.dueAtMs),
              completed: Value(task.completed),
              position: task.position,
              integrationType: integrationType,
              integrationId: integrationId,
              externalId: taskExternal,
              updatedAtMs: updatedAt,
            ),
          );
    }

    if (seenTaskExternalIds.isEmpty) {
      await (db.delete(db.tasks)..where(
            (t) =>
                t.taskListId.equals(listId) &
                t.integrationId.equals(integrationId),
          ))
          .go();
    } else {
      await (db.delete(db.tasks)..where(
            (t) =>
                t.taskListId.equals(listId) &
                t.integrationId.equals(integrationId) &
                t.externalId.isNotIn(seenTaskExternalIds),
          ))
          .go();
    }
  }

  if (seenListExternalIds.isEmpty) {
    await (db.delete(db.taskLists)..where(
          (t) =>
              t.integrationId.equals(integrationId) &
              t.boardKey.equals(boardKey),
        ))
        .go();
  } else {
    await (db.delete(db.taskLists)..where(
          (t) =>
              t.integrationId.equals(integrationId) &
              t.boardKey.equals(boardKey) &
              t.externalId.isNotIn(seenListExternalIds),
        ))
        .go();
  }
}
