import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screen_rotator.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('arrow keys navigate slides and show timeline overlay', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await _seedTwoSlideProgram(db);
    addTearDown(db.close);

    await _pumpRotator(tester, db);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_nav_overlay_timeline')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_nav_overlay_timeline')), findsOneWidget);
    expect(find.byKey(const Key('screen_nav_current_index')), findsOneWidget);
    expect(find.textContaining('alpha_screen'), findsWidgets);
    expect(find.textContaining('beta_screen'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_nav_overlay_timeline')), findsOneWidget);
  });

  testWidgets('shows end of history message at oldest program boundary', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await _seedTwoSlideProgram(db);
    addTearDown(db.close);

    await _pumpRotator(tester, db);
    await tester.pumpAndSettle();

    // Advance long enough for at least one new program to be curated so there is
    // history to move through.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_nav_end_history_message')), findsOneWidget);
  });

  testWidgets('overlay fades out after idle timeout', (tester) async {
    final db = openMemoryDatabase();
    await _seedTwoSlideProgram(db);
    addTearDown(db.close);

    await _pumpRotator(tester, db);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_nav_overlay_root')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_nav_overlay_root')), findsNothing);
  });

  testWidgets('arrow up and down do not drive screen navigation overlay', (tester) async {
    final db = openMemoryDatabase();
    await _seedTwoSlideProgram(db);
    addTearDown(db.close);

    await _pumpRotator(tester, db);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screen_nav_overlay_timeline')), findsNothing);
  });
}

Future<void> _seedTwoSlideProgram(AppDatabase db) async {
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        const ConfigKeyValuesCompanion(
          key: Value(kCuratorProgramDurationSecondsKvKey),
          value: Value('2'),
        ),
      );
  await db.into(db.configKeyValues).insertOnConflictUpdate(
        const ConfigKeyValuesCompanion(
          key: Value(kCuratorHistoryDepthKvKey),
          value: Value('4'),
        ),
      );

  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'alpha_screen',
          name: 'Alpha',
          screenType: 'static_text',
          configJson: const Value('{"text":"Alpha"}'),
          dwellSeconds: const Value(1),
          frequencyWeight: const Value(100),
          minGapBetweenShowsSeconds: const Value(0),
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'beta_screen',
          name: 'Beta',
          screenType: 'static_text',
          configJson: const Value('{"text":"Beta"}'),
          dwellSeconds: const Value(1),
          frequencyWeight: const Value(100),
          minGapBetweenShowsSeconds: const Value(0),
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _pumpRotator(WidgetTester tester, AppDatabase db) async {
  final file = File('${Directory.systemTemp.path}/waddle-view-test-key.txt');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ScreenRotator(
          db: db,
          blobs: FakeBlobStore(),
          localRestBaseUrl: 'http://127.0.0.1:8787',
          adminBaseUrl: 'http://127.0.0.1:8787/admin',
          instanceIdFile: file,
        ),
      ),
    ),
  );
}
