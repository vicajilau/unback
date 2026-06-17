// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:background_remover/main.dart';

void main() {
  testWidgets('Smoke test background remover app launch', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BackgroundRemoverApp());

    // Verify that the title and upload prompt are present.
    expect(find.text('Background Remover'), findsOneWidget);
    expect(find.text('Load Image to Remove Background'), findsOneWidget);
  });
}
