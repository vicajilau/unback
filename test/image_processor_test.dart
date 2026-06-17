import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:background_remover/core/image_processor.dart';

void main() {
  group('ImageProcessor Tests', () {
    test('removeBackground removes matching colors', () {
      // Create a 2x2 test image: top-left is red, others are green
      final testImage = img.Image(width: 2, height: 2, numChannels: 3);

      // Set pixel values
      testImage.setPixelRgb(0, 0, 255, 0, 0); // Red (background to remove)
      testImage.setPixelRgb(1, 0, 0, 255, 0); // Green
      testImage.setPixelRgb(0, 1, 0, 255, 0); // Green
      testImage.setPixelRgb(1, 1, 0, 255, 0); // Green

      final pngBytes = Uint8List.fromList(img.encodePng(testImage));

      // Process removal targeting red
      final resultBytes = ImageProcessor.removeBackground({
        'bytes': pngBytes,
        'r': 255,
        'g': 0,
        'b': 0,
        'threshold': 10.0,
        'smoothness': 0.0,
      });

      // Decode processed result
      final resultImage = img.decodeImage(resultBytes);
      expect(resultImage, isNotNull);
      expect(resultImage!.numChannels, 4);

      // Check pixel transparency
      // Top-left should be fully transparent (alpha = 0)
      final pixel00 = resultImage.getPixel(0, 0);
      expect(pixel00.a, 0);

      // Others should be fully opaque (alpha = 255)
      final pixel10 = resultImage.getPixel(1, 0);
      expect(pixel10.a, 255);
      expect(pixel10.g, 255);
    });
  });
}
