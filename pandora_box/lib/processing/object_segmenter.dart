import 'dart:typed_data';

class ObjectSegmenter {
  /// Generates a strict binary mask (true = object, false = background)
  /// using a highly aggressive Depth Gate.
  static List<bool> generateMask({
    required Float32List depthMap,
    required int width,
    required int height,
    double depthTolerance = 0.08, // STRICT! Only 8% of the depth range.
  }) {
    final mask = List<bool>.filled(width * height, false);

    // 1. Sample the exact center of the image (The core of the mug)
    double centerSum = 0;
    int centerCount = 0;
    const int sampleRadius = 20;
    final int cx = width ~/ 2;
    final int cy = height ~/ 2;

    for (int y = cy - sampleRadius; y <= cy + sampleRadius; y++) {
      for (int x = cx - sampleRadius; x <= cx + sampleRadius; x++) {
        final idx = y * width + x;
        if (idx >= 0 && idx < depthMap.length) {
          centerSum += depthMap[idx];
          centerCount++;
        }
      }
    }

    final double objectCoreDepth =
        centerCount > 0 ? (centerSum / centerCount) : 0.6;

    // 2. The Strict Cutoff (The Scalpel)
    // We only keep pixels that are physically connected to the mug's depth.
    final double minDepth = objectCoreDepth - depthTolerance;
    final double maxDepth = objectCoreDepth + depthTolerance;

    for (int i = 0; i < mask.length; i++) {
      final depth = depthMap[i];

      // If the pixel is strictly within the mug's depth slice, keep it.
      if (depth >= minDepth && depth <= maxDepth) {
        mask[i] = true;
      }
    }

    // 3. Morphological dilation to smooth the edges of the cut
    return _dilate(mask, width, height, radius: 2);
  }

  /// Expands the mask by [radius] pixels to ensure we don't accidentally shave off the mug's handle
  static List<bool> _dilate(List<bool> mask, int width, int height,
      {int radius = 2}) {
    final out = List<bool>.from(mask);
    for (int y = radius; y < height - radius; y++) {
      for (int x = radius; x < width - radius; x++) {
        if (mask[y * width + x]) continue;

        outer:
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            if (mask[(y + dy) * width + (x + dx)]) {
              out[y * width + x] = true;
              break outer;
            }
          }
        }
      }
    }
    return out;
  }
}
