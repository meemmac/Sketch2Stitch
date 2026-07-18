// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sketch2stitch/main.dart';

void main() {
  testWidgets('App loads welcome screen smoke test', (WidgetTester tester) async {
    // Set a large screen size to prevent card overflows on default small test screen sizes.
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(const Sketch2StitchApp());

    // Verify that our app name is displayed.
    expect(find.text('Sketch2Stitch'), findsWidgets);
  });
}
