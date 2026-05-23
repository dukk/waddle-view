import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/slide_vertical_scroll_timing.dart';
import 'package:waddle_display/display/screens/stock_quotes/stock_quotes_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_display/theme/display_theme.dart';

import '../helpers/memory_database.dart';

Future<void> _seedManyStockSymbols(AppDatabase db, {required int count}) async {
  for (var i = 0; i < count; i++) {
    final id = 'sym$i';
    final ticker = 'T${i.toString().padLeft(2, '0')}';
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: id,
            symbol: ticker,
            displayName: Value('Company $i'),
          ),
        );
    await db
        .into(db.stockQuotes)
        .insert(
          StockQuotesCompanion.insert(
            symbolId: id,
            currentPrice: Value(100.0 + i),
            percentChange: Value(i.isEven ? 1.0 : -0.5),
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1000 + i),
          ),
        );
  }
}

void main() {
  testWidgets('renders price and percent change for each enabled symbol', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
            displayName: const Value('Apple'),
          ),
        );
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'msft',
            symbol: 'MSFT',
            displayName: const Value('Microsoft'),
          ),
        );
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'goog',
            symbol: 'GOOG',
            displayName: const Value('Alphabet'),
            enabled: const Value(false),
          ),
        );
    await db
        .into(db.stockQuotes)
        .insert(
          StockQuotesCompanion.insert(
            symbolId: 'aapl',
            currentPrice: const Value(261.74),
            percentChange: const Value(1.23),
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        );
    await db
        .into(db.stockQuotes)
        .insert(
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

  testWidgets('renders symbol with no quote yet using em-dash placeholders', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsStockSymbols)
        .insert(
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

  testWidgets('price line does not overflow with large text scaling', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'brk',
            symbol: 'BRK.A',
            displayName: const Value('Berkshire'),
          ),
        );
    await db
        .into(db.stockQuotes)
        .insert(
          StockQuotesCompanion.insert(
            symbolId: 'brk',
            currentPrice: const Value(628421.03),
            percentChange: const Value(0.01),
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1000),
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
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 640,
              child: StockQuotesSlideWidget(
                db: db,
                slide: slide,
                spec: spec,
                theme: theme,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(r'$628421.03'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('wrap flows right to left with first symbol on the right', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
            displayName: const Value('Apple'),
          ),
        );
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'msft',
            symbol: 'MSFT',
            displayName: const Value('Microsoft'),
          ),
        );
    await db
        .into(db.stockQuotes)
        .insert(
          StockQuotesCompanion.insert(
            symbolId: 'aapl',
            currentPrice: const Value(100),
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        );
    await db
        .into(db.stockQuotes)
        .insert(
          StockQuotesCompanion.insert(
            symbolId: 'msft',
            currentPrice: const Value(200),
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

    final aaplBox = tester.getRect(find.text('AAPL'));
    final msftBox = tester.getRect(find.text('MSFT'));
    expect(aaplBox.center.dx, greaterThan(msftBox.center.dx));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('few symbols report minReadMs dwell when not scrollable', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(id: 'aapl', symbol: 'AAPL'),
        );
    var reported = 0;
    const spec = ParsedWidgetSpec(
      type: 'stock_quotes',
      slot: 'main',
      config: {'minReadMs': 9000},
    );
    const slide = ResolvedSlide(
      screenId: 'stock_quotes',
      dwellMs: 5000,
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
            onReportDesiredDwell: (ms) => reported = ms,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reported, 9000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('many symbols report extended dwell and scroll after delay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = openMemoryDatabase();
    await warmDatabase(db);
    await _seedManyStockSymbols(db, count: 24);

    var reported = 0;
    const spec = ParsedWidgetSpec(
      type: 'stock_quotes',
      slot: 'main',
      config: {
        'scrollDelayMs': 80,
        'trailingHoldMs': 40,
        'scrollPixelsPerSecond': 800.0,
        'minReadMs': 500,
      },
    );
    const slide = ResolvedSlide(
      screenId: 'stock_quotes',
      dwellMs: 500,
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
            onReportDesiredDwell: (ms) => reported = ms,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollFinder = find.descendant(
      of: find.byKey(const Key('stock_quotes_wrap_scroll')),
      matching: find.byType(Scrollable),
    );
    final scrollState = tester.state<ScrollableState>(scrollFinder);
    final position = scrollState.position;
    expect(position.maxScrollExtent, greaterThan(50));

    final expectedMin = desiredDwellMsForVerticalScroll(
      baseDwellMs: slide.dwellMs,
      minReadMs: 500,
      scrollable: true,
      scrollDelayMs: 80,
      trailingHoldMs: 40,
      maxScrollExtent: position.maxScrollExtent,
      scrollPixelsPerSecond: 800,
    );
    expect(reported, expectedMin);
    expect(reported, greaterThan(slide.dwellMs));

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(position.maxScrollExtent, 3.0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  });
}
