import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/stock_quotes/stock_quotes_slide_widget.dart';
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/theme/display_theme.dart';

import '../helpers/memory_database.dart';

void main() {
  testWidgets('renders price and percent change for each enabled symbol', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
            displayName: const Value('Apple'),
          ),
        );
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: 'msft',
            symbol: 'MSFT',
            displayName: const Value('Microsoft'),
          ),
        );
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: 'goog',
            symbol: 'GOOG',
            displayName: const Value('Alphabet'),
            enabled: const Value(false),
          ),
        );
    await db.into(db.stockQuotes).insert(
          StockQuotesCompanion.insert(
            symbolId: 'aapl',
            currentPrice: const Value(261.74),
            percentChange: const Value(1.23),
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        );
    await db.into(db.stockQuotes).insert(
          StockQuotesCompanion.insert(
            symbolId: 'msft',
            currentPrice: const Value(412.50),
            percentChange: const Value(-0.42),
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(2000),
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
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: StockQuotesSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('MSFT'), findsOneWidget);
    expect(find.text('GOOG'), findsNothing);
    expect(find.text('\$261.74'), findsOneWidget);
    expect(find.text('\$412.50'), findsOneWidget);
    expect(find.textContaining('+1.23%'), findsOneWidget);
    expect(find.textContaining('-0.42%'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('shows empty placeholder when no quotes exist', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
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
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: StockQuotesSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Stock quotes unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('renders symbol with no quote yet using em-dash placeholders',
      (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
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
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: StockQuotesSlideWidget(
            db: db,
            slide: slide,
            spec: spec,
            theme: theme,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AAPL'), findsOneWidget);
    expect(find.textContaining('—'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });
}
