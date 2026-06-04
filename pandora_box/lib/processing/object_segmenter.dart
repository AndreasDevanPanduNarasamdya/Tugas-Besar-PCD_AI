import 'dart:typed_data';

class ObjectSegmenter {
  /// Generates a strict binary mask (true = object, false = background)
  /// using a highly aggressive Depth Gate + Flood Fill.
  static List<bool> generateMask({
    required Float32List depthMap,
    required int width,
    required int height,
    double depthTolerance = 0.08,
  }) {
    final mask = List<bool>.filled(width * height, false);

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
    final double minDepth = objectCoreDepth - depthTolerance;
    final double maxDepth = objectCoreDepth + depthTolerance;

    for (int i = 0; i < mask.length; i++) {
      final depth = depthMap[i];
      if (depth >= minDepth && depth <= maxDepth) {
        mask[i] = true;
      }
    }

    // Dilate first to close small boundary gaps, then flood fill for absolute solidity!
    final dilated = _dilate(mask, width, height, radius: 2);
    return _fillHoles(dilated, width, height);
  }

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

  /// THE CURE FOR SWISS CHEESE: Flood fills the true background from the borders.
  static List<bool> _fillHoles(List<bool> mask, int width, int height) {
    final out = List<bool>.filled(width * height, true);
    final queue = <int>[];

    // Seed the queue with the outer borders
    for (int x = 0; x < width; x++) {
      queue.add(x);
      queue.add((height - 1) * width + x);
    }
    for (int y = 0; y < height; y++) {
      queue.add(y * width);
      queue.add(y * width + (width - 1));
    }

    int head = 0;
    while (head < queue.length) {
      final idx = queue[head++];

      // If it's a hole in the original mask, and we haven't flooded it yet
      if (!mask[idx] && out[idx]) {
        out[idx] = false; // It is true background

        final x = idx % width;
        final y = idx ~/ width;

        if (x > 0) queue.add(idx - 1);
        if (x < width - 1) queue.add(idx + 1);
        if (y > 0) queue.add(idx - width);
        if (y < height - 1) queue.add(idx + width);
      }
    }
    return out; // Everything left over is purely solid silhouette!
  }
}
