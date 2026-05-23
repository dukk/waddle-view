import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/tasks/task_sync_upsert.dart';

void main() {
  test('syncTaskBoardSnapshot upserts lists and tasks and prunes stale rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final updated = DateTime.utc(2025, 6, 1, 12);
    await syncTaskBoardSnapshot(
      db,
      integrationType: 'tasks_trello',
      integrationId: 'default_tasks_trello',
      boardKey: 'board1',
      updatedAt: updated,
      lists: [
        TaskListSnapshot(
          externalId: 'listA',
          label: 'To Do',
          columnOrder: 1,
          tasks: [
            TaskSnapshot(
              externalId: 'card1',
              title: 'First',
              completed: false,
              position: 1,
            ),
          ],
        ),
      ],
    );

    final lists = await db.select(db.taskLists).get();
    expect(lists, hasLength(1));
    expect(lists.single.label, 'To Do');
    expect(lists.single.boardKey, 'board1');

    final tasks = await db.select(db.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'First');

    await syncTaskBoardSnapshot(
      db,
      integrationType: 'tasks_trello',
      integrationId: 'default_tasks_trello',
      boardKey: 'board1',
      updatedAt: updated,
      lists: [
        TaskListSnapshot(
          externalId: 'listB',
          label: 'Done',
          columnOrder: 2,
          tasks: [
            TaskSnapshot(
              externalId: 'card2',
              title: 'Second',
              completed: true,
              position: 1,
            ),
          ],
        ),
      ],
    );

    final listsAfter = await db.select(db.taskLists).get();
    expect(listsAfter, hasLength(1));
    expect(listsAfter.single.externalId, 'listB');

    final tasksAfter = await db.select(db.tasks).get();
    expect(tasksAfter, hasLength(1));
    expect(tasksAfter.single.title, 'Second');
  });

  test('schema 48 to 49 creates task tables on upgrade', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('PRAGMA user_version = 48');
      },
    );
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');
    expect(db.schemaVersion, 49);
    expect(await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='task_lists'",
    ).get(), isNotEmpty);
    expect(await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='tasks'",
    ).get(), isNotEmpty);
    await db.close();
  });
}
