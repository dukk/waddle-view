import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/controller_invite/controller_invite_slide_widget.dart';
import 'package:waddle_display/display/viewer_invite_runtime.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

void main() {
  test('buildControllerJoinUri builds /join with query params', () {
    final u = buildControllerJoinUri(
      controllerBaseUrl: 'http://localhost:5173',
      displayApiBaseUrl: 'http://192.168.0.5:8787',
      viewerRegistrationSecret: 'abc',
    );
    expect(u, isNotNull);
    expect(u!.path, '/join');
    expect(u.queryParameters['api'], 'http://192.168.0.5:8787');
    expect(u.queryParameters['secret'], 'abc');
  });

  testWidgets('controller invite shows QR when controller URL is known', (
    tester,
  ) async {
    const spec = ParsedWidgetSpec(
      type: 'controller_invite',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ControllerInviteSlideWidget(
            displayApiBaseUrl: 'http://127.0.0.1:8787',
            viewerInviteRuntime: const ViewerInviteRuntime(
              controllerPublicUrl: 'http://example.com:8080',
              viewerRegistrationSecret: 'sekrit',
            ),
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.textContaining('http://example.com:8080/join'), findsOneWidget);
  });
}
