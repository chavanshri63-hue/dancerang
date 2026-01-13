// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dancerang/main.dart';

void main() {
  testWidgets('Splash screen shows and navigates to login', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that splash screen shows
    expect(find.text('DANCER'), findsOneWidget);
    expect(find.text('NG'), findsOneWidget);

    // Wait for navigation to complete
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Should navigate to login screen after splash
    expect(find.text('Login'), findsOneWidget);
  });
}