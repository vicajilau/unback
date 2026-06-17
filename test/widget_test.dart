import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:cross_file/cross_file.dart';
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

  testWidgets('Reset adjustments button works correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BackgroundRemoverApp());

    // Get the state of DashboardScreen dynamically since state class is private
    final stateFinder = find.byType(DashboardScreen);
    final dynamic state = tester.state(stateFinder);

    // Create a 2x2 test image bytes
    final testImage = img.Image(width: 2, height: 2, numChannels: 3);
    testImage.setPixelRgb(0, 0, 255, 0, 0); // Red
    final bytes = Uint8List.fromList(img.encodePng(testImage));

    // Load image via XFile
    final file = XFile.fromData(bytes, name: 'test.png');
    await state.loadImage(file);
    await tester.pumpAndSettle();

    // Verify initial values
    expect(state._threshold, 30.0);
    expect(state._smoothness, 20.0);

    // Modify values
    state.setState(() {
      state._threshold = 100.0;
      state._smoothness = 80.0;
    });
    await tester.pump();

    expect(state._threshold, 100.0);
    expect(state._smoothness, 80.0);

    // Find and tap reset button
    final resetButton = find.byTooltip('Reset adjustments');
    expect(resetButton, findsOneWidget);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    // Verify values are reset
    expect(state._threshold, 30.0);
    expect(state._smoothness, 20.0);
  });
}
