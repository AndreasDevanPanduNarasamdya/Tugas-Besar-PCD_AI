import 'dart:typed_data';
import 'dart:math';

class BilateralFilter {
  /// Apply bilateral filter to a depth map
  /// Smooths flat surfaces while preserving sharp edges
  /// Input: Float32List of size width*height (normalized 0-1 depth)
  /// Output: Float32List same size, filtered
  static Float32List apply({
    required Float32List depthMap,
    required int width,
    required int height,
    int radius = 3,
    double sigmaSpace = 2.0,
    double sigmaDepth = 0.1,
  }) {
    final output = Float32List(width * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final centerIdx = y * width + x;
        final centerDepth = depthMap[centerIdx];

        double weightSum = 0.0;
        double valueSum = 0.0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final nx = x + dx;
            final ny = y + dy;

            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;

            final neighborIdx = ny * width + nx;
            final neighborDepth = depthMap[neighborIdx];

            // Spatial weight — penalize distant pixels
            final spatialDist = sqrt(dx * dx + dy * dy);
            final spatialWeight = exp(
                -(spatialDist * spatialDist) / (2 * sigmaSpace * sigmaSpace));

            // Depth weight — penalize pixels with very different depth
            final depthDiff = centerDepth - neighborDepth;
            final depthWeight =
                exp(-(depthDiff * depthDiff) / (2 * sigmaDepth * sigmaDepth));

            final weight = spatialWeight * depthWeight;
            weightSum += weight;
            valueSum += weight * neighborDepth;
          }
        }

        output[centerIdx] = weightSum > 0 ? valueSum / weightSum : centerDepth;
      }
    }

    return output;
  }
}
