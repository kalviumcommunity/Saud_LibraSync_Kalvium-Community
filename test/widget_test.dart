// Basic smoke test for the LibraSync application shell.

import 'package:flutter_test/flutter_test.dart';

import 'package:librasync/main.dart';

void main() {
  testWidgets('LibraSync app renders home screen', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const LibraSyncApp());

    // Verify the app title is visible.
    expect(find.text('LibraSync'), findsOneWidget);

    // Verify the welcome banner is rendered.
    expect(find.text('Welcome to LibraSync'), findsOneWidget);
  });
}
