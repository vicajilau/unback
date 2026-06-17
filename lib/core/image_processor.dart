import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// A utility class for performing image background removal.
class ImageProcessor {
  /// Processes the image to make the specified background color transparent.
  /// This is designed to run in a background isolate via Flutter's `compute`.
  ///
  /// The [params] map should contain:
  /// - `bytes`: [Uint8List] raw image bytes.
  /// - `r`: [int] Red channel value of background color (0-255).
  /// - `g`: [int] Green channel value of background color (0-255).
  /// - `b`: [int] Blue channel value of background color (0-255).
  /// - `threshold`: [double] Color match distance tolerance (0-255).
  /// - `smoothness`: [double] Smooth transition range (0-255).
  static Uint8List removeBackground(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int bgR = params['r'];
    final int bgG = params['g'];
    final int bgB = params['b'];
    final double threshold = params['threshold'].toDouble();
    final double smoothness = params['smoothness'].toDouble();

    // Decode the image
    final img.Image? decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    // Ensure the image has 4 channels (RGBA) to support transparency
    img.Image rgbaImage = decodedImage.numChannels == 4
        ? decodedImage
        : decodedImage.convert(numChannels: 4);

    final double thresholdMin = threshold;
    final double thresholdMax = threshold + smoothness;

    // Process pixels
    for (final pixel in rgbaImage) {
      final int r = pixel.r.toInt();
      final int g = pixel.g.toInt();
      final int b = pixel.b.toInt();

      // Calculate Euclidean distance in RGB space
      final double distance = sqrt(
        pow(r - bgR, 2) + pow(g - bgG, 2) + pow(b - bgB, 2),
      );

      if (distance < thresholdMin) {
        // Fully transparent
        pixel.a = 0;
      } else if (distance < thresholdMax && smoothness > 0) {
        // Semi-transparent gradient for antialiasing
        final double ratio = (distance - thresholdMin) / smoothness;
        final int originalAlpha = pixel.a.toInt();
        pixel.a = (originalAlpha * ratio).clamp(0, 255).round();
      }
      // Otherwise: keep original opacity
    }

    // Re-encode to PNG to preserve transparency
    return Uint8List.fromList(img.encodePng(rgbaImage));
  }
}
