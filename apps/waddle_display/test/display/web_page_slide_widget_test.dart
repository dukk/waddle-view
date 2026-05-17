import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/web_page/web_page_session.dart';
import 'package:waddle_display/display/screens/web_page/web_page_slide_widget.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

void main() {
  tearDown(() {
    WebPagePrepareCache.debugLoader = null;
    WebPagePrepareCache.instance.disposeAll();
  });

  testWidgets('shows preloaded web view', (tester) async {
    const spec = ParsedWidgetSpec(
      type: 'web_page',
      slot: 'main',
      config: {'url': 'https://example.com'},
    );
    WebPagePrepareCache.debugLoader =
        (spec, cfg) async => FakeWebPagePreparedSession(config: cfg);
    await WebPagePrepareCache.instance.preload(spec);

    var reportedDwell = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebPageSlideWidget(
            slide: const ResolvedSlide(
              screenId: 's1',
              dwellMs: 8000,
              layoutJson: '{}',
            ),
            spec: spec,
            onReportDesiredDwell: (ms) => reportedDwell = ms,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('web_page_fake_view')), findsOneWidget);
    expect(reportedDwell, greaterThanOrEqualTo(4000));
  });

  testWidgets('shows error when url missing', (tester) async {
    const spec = ParsedWidgetSpec(
      type: 'web_page',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebPageSlideWidget(
            slide: const ResolvedSlide(
              screenId: 's1',
              dwellMs: 5000,
              layoutJson: '{}',
            ),
            spec: spec,
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('http/https required'), findsOneWidget);
  });

  testWidgets('shows error when not preloaded', (tester) async {
    const spec = ParsedWidgetSpec(
      type: 'web_page',
      slot: 'main',
      config: {'url': 'https://example.com'},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebPageSlideWidget(
            slide: const ResolvedSlide(
              screenId: 's1',
              dwellMs: 5000,
              layoutJson: '{}',
            ),
            spec: spec,
            onReportDesiredDwell: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Web page was not preloaded'), findsOneWidget);
  });
}
