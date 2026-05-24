import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/display_memory_image.dart';

void main() {
  testWidgets('DisplayMemoryImage does not throw on corrupt bytes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DisplayMemoryImage(
            bytes: Uint8List.fromList([0, 1, 2, 3]),
            width: 40,
            height: 40,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
