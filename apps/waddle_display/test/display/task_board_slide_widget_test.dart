import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/task_board/task_board_slide_widget.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_display/theme/display_theme.dart';

import '../helpers/memory_database.dart';

void main() {
  testWidgets('renders columns and open tasks for boardKey', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final updated = DateTime.utc(2025, 1, 1);
    await db.into(db.taskLists).insert(
          TaskListsCompanion.insert(
            id: 'list1',
            label: 'To Do',
            boardKey: 'board_a',
            columnOrder: 1,
            integrationType: 'tasks_trello',
            integrationId: kDefaultTasksTrelloIntegrationId,
            externalId: 'ext1',
            updatedAtMs: updated,
          ),
        );
    await db.into(db.tasks).insert(
          TasksCompanion.insert(
            id: 't1',
            taskListId: 'list1',
            title: 'Ship it',
            integrationType: 'tasks_trello',
            integrationId: kDefaultTasksTrelloIntegrationId,
            externalId: 'c1',
            position: 1,
            updatedAtMs: updated,
          ),
        );
    await db.into(db.tasks).insert(
          TasksCompanion.insert(
            id: 't2',
            taskListId: 'list1',
            title: 'Done task',
            completed: const Value(true),
            integrationType: 'tasks_trello',
            integrationId: kDefaultTasksTrelloIntegrationId,
            externalId: 'c2',
            position: 2,
            updatedAtMs: updated,
          ),
        );

    const spec = ParsedWidgetSpec(
      type: 'task_board',
      slot: 'main',
      config: {'boardKey': 'board_a'},
    );
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 800,
            child: TaskBoardSlideWidget(db: db, spec: spec, theme: theme),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Ship it'), findsOneWidget);
    expect(find.text('Done task'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });
}
