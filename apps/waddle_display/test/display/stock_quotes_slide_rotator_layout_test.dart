import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/stock_quotes/stock_quotes_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

/// Mirrors [_SlideContent] for a lone `stock_quotes` widget after the rotator
/// full-bleed branch: bounded viewport via [SizedBox.expand].
void main() {
  testWidgets('StockQuotesSlideWidget lays out inside rotator expand viewport', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
            displayName: const Value('Apple'),
          ),
        );

    const spec = ParsedWidgetSpec(
      type: 'stock_quotes',
      slot: 'main',
      config: {},
    );
    const slide = ResolvedSlide(
      screenId: 'stock_quotes',
      dwellMs: 10000,
      layoutJson:
          '{"v":1,"layout":"single","widgets":[{"type":"stock_quotes","slot":"main","config":{}}]}',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Center(
              child: SizedBox.expand(
                child: StockQuotesSlideWidget(
                  db: db,
                  slide: slide,
                  spec: spec,
                  theme: ThemeData.light(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AAPL'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await db.close();
  });
}
