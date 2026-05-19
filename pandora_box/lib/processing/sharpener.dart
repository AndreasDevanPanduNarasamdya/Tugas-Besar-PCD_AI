import 'dart:typed_data';
import 'package:image/image.dart' as img;

class Sharpener {
  /// Apply unsharp masking to an image
  /// strength: 0.0 = no effect, 1.0 = full sharpening
  static img.Image apply({
    required img.Image source,
    double strength = 0.5,
    int blurRadius = 1,
  }) {
    // Step 1: Blur the image
    final blurred = img.gaussianBlur(source, radius: blurRadius);

    // Step 2: Sharpened = Original + strength * (Original - Blurred)
    final result = img.Image(
      width: source.width,
      height: source.height,
    );

    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final orig = source.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r = (orig.r + strength * (orig.r - blur.r)).round().clamp(0, 255);
        final g = (orig.g + strength * (orig.g - blur.g)).round().clamp(0, 255);
        final b = (orig.b + strength * (orig.b - blur.b)).round().clamp(0, 255);

        result.setPixelRgb(x, y, r, g, b);
      }
    }

    return result;
  }

  /// Apply sharpening to a Float32List depth map
  /// Uses same unsharp masking principle
  static Float32List applyToDepth({
    required Float32List depthMap,
    required int width,
    required int height,
    double strength = 0.3,
    int blurRadius = 1,
  }) {
    // Gaussian blur on depth map
    final blurred = _gaussianBlurDepth(depthMap, width, height, blurRadius);

    final result = Float32List(width * height);
    for (int i = 0; i < depthMap.length; i++) {
      result[i] =
          (depthMap[i] + strength * (depthMap[i] - blurred[i])).clamp(0.0, 1.0);
    }

    return result;
  }

  static Float32List _gaussianBlurDepth(
    Float32List depthMap,
    int width,
    int height,
    int radius,
  ) {
    final output = Float32List(width * height);

    // Simple box blur as approximation
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double sum = 0;
        int count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final nx = (x + dx).clamp(0, width - 1);
            final ny = (y + dy).clamp(0, height - 1);
            sum += depthMap[ny * width + nx];
            count++;
          }
        }

        output[y * width + x] = sum / count;
      }
    }

    return output;
  }
}
