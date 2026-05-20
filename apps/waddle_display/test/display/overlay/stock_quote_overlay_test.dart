import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/stock_quote_overlay.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';
import 'package:waddle_shared/persistence/display_overlay_stock_quote_settings.dart';

import '../../helpers/memory_database.dart';

void main() {
  testWidgets('StockQuoteOverlay shows quote tile at placement', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
            displayName: const Value('Apple'),
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

    const settings = StockQuoteOverlaySettings(
      placement: ClockOverlayPlacement(
        x: 0.5,
        y: 0.1,
        scale: 0.25,
        opacity: 1.0,
      ),
      symbolId: 'aapl',
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: StockQuoteOverlay(
              db: db,
              settingsList: const [settings],
              theme: theme,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('\$261.74'), findsOneWidget);
    expect(find.textContaining('+1.23%'), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, closeTo(400, 0.01));
    expect(positioned.top, closeTo(60, 0.01));
    expect(positioned.width, closeTo(150, 0.01));

    await db.close();
  });

  testWidgets('StockQuoteOverlay shows unavailable for unknown symbolId', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    const settings = StockQuoteOverlaySettings(
      placement: ClockOverlayPlacement.defaults,
      symbolId: 'missing',
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: StockQuoteOverlay(
              db: db,
              settingsList: const [settings],
              theme: theme,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stock quote unavailable'), findsOneWidget);
    await db.close();
  });
}
