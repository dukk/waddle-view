import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/curator/ticker_item.dart';
import 'package:waddle_view/marquee_cycle_gate.dart';
import 'package:waddle_view/theme/display_theme.dart';
import 'package:waddle_view/ticker/memory_ticker_curated_repository.dart';
import 'package:waddle_view/ticker/ticker_marquee.dart';

void main() {
  testWidgets('shows em dash when repository has no items', (tester) async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TickerMarquee(repository: repo),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('\u2014'), findsOneWidget);
  });

  testWidgets('uses themed secondary gradient for ticker background', (
    tester,
  ) async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    final theme = DisplayTheme.build();
    final expected = theme.extension<PaletteTertiaryLayers>()!;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: TickerMarquee(repository: repo),
        ),
      ),
    );
    await tester.pump();
    final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.gradient, equals(expected.secondaryPairGradient));
  });

  testWidgets('cycleGate completes wait when strip is empty', (tester) async {
    final gate = MarqueeCycleGate();
    gate.onCurationWrittenExpectMarqueeLoop();
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TickerMarquee(repository: repo, cycleGate: gate),
        ),
      ),
    );
    await tester.pump();
    await gate.awaitPriorMarqueePresentationIfAny();
    gate.dispose();
  });

  testWidgets('cycleGate notified when items clear after having content', (
    tester,
  ) async {
    final gate = MarqueeCycleGate();
    gate.onCurationWrittenExpectMarqueeLoop();
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'a', body: 'Hi'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: TickerMarquee(repository: repo, cycleGate: gate),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await repo.replaceAll([]);
    await tester.pump();
    await gate.awaitPriorMarqueePresentationIfAny();
    gate.dispose();
  });

  testWidgets('cycleGate can be attached after animation has started', (
    tester,
  ) async {
    final gate = MarqueeCycleGate();
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'a', body: 'Hello'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: TickerMarquee(repository: repo),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: TickerMarquee(repository: repo, cycleGate: gate),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 2));
    }
    expect(tester.takeException(), isNull);
    gate.dispose();
  });

  testWidgets('renders RSS item as RichText when theme provides styles', (
    tester,
  ) async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      TickerItem(
        kind: 'news',
        body: '[Src] Head Sum',
        rss: const TickerRssSegments(
          sourceTitle: 'Src',
          sourceIconName: 'public',
          articleTitle: 'Head',
          summary: 'Sum',
          showSource: true,
        ),
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: DisplayTheme.build(),
        home: Scaffold(
          body: TickerMarquee(repository: repo, pixelsPerSecond: 200),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(RichText), findsWidgets);
    expect(find.byIcon(Icons.public), findsNWidgets(2));
  });

  testWidgets('renders duplicate segments with separators', (tester) async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'a', body: 'Hello'),
      const TickerItem(kind: 'b', body: 'World'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TickerMarquee(repository: repo, pixelsPerSecond: 200),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Hello'), findsNWidgets(2));
    expect(find.text('World'), findsNWidgets(2));
    expect(find.text('\u00B7'), findsNWidgets(2));
  });

  testWidgets('renders weather ticker item with weather icon', (tester) async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'weather', body: 'Atlanta: 72° · cloudy'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TickerMarquee(repository: repo, pixelsPerSecond: 200),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.cloud), findsNWidgets(2));
  });

  testWidgets('repeats for several cycles without exceptions', (tester) async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'a', body: 'Hi'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: TickerMarquee(repository: repo, pixelsPerSecond: 400),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow strip with long text does not RenderFlex overflow', (
    tester,
  ) async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    final long = List.filled(120, 'Word').join(' ');
    await repo.replaceAll([TickerItem(kind: 'a', body: long)]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              child: TickerMarquee(repository: repo, pixelsPerSecond: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation controller shows ticker history overlay and boundaries', (
    tester,
  ) async {
    final repo = MemoryTickerCuratedRepository();
    final navigation = TickerMarqueeNavigationController();
    addTearDown(repo.dispose);
    addTearDown(navigation.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'news', body: 'headline'),
      const TickerItem(kind: 'weather', body: 'forecast'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: TickerMarquee(
                repository: repo,
                pixelsPerSecond: 40,
                navigationController: navigation,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    navigation.navigateForward();
    await tester.pumpAndSettle();
    expect(find.text('weather'), findsWidgets);

    navigation.navigateForward();
    await tester.pumpAndSettle();
    expect(
      find.text('End of current ticker program. Waiting for a new program.'),
      findsOneWidget,
    );
  });
}
