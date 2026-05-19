import 'dart:typed_data';
import 'dart:math';

class EdgeDetector {
  /// Detect edges in depth map using Sobel operator
  /// Returns a Float32List where high values = edges
  static Float32List detectEdges({
    required Float32List depthMap,
    required int width,
    required int height,
  }) {
    final edges = Float32List(width * height);

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Sobel X kernel: [-1,0,1,-2,0,2,-1,0,1]
        final gx = -depthMap[(y - 1) * width + (x - 1)] +
            depthMap[(y - 1) * width + (x + 1)] -
            2 * depthMap[y * width + (x - 1)] +
            2 * depthMap[y * width + (x + 1)] -
            depthMap[(y + 1) * width + (x - 1)] +
            depthMap[(y + 1) * width + (x + 1)];

        // Sobel Y kernel: [-1,-2,-1,0,0,0,1,2,1]
        final gy = -depthMap[(y - 1) * width + (x - 1)] -
            2 * depthMap[(y - 1) * width + x] -
            depthMap[(y - 1) * width + (x + 1)] +
            depthMap[(y + 1) * width + (x - 1)] +
            2 * depthMap[(y + 1) * width + x] +
            depthMap[(y + 1) * width + (x + 1)];

        edges[y * width + x] = sqrt(gx * gx + gy * gy);
      }
    }

    return edges;
  }

  /// Generate a binary mask — true = valid pixel, false = edge/discard
  /// Pixels at depth discontinuities are marked for removal
  static List<bool> generateValidMask({
    required Float32List depthMap,
    required int width,
    required int height,
    double edgeThreshold = 0.05,
  }) {
    final edges = detectEdges(
      depthMap: depthMap,
      width: width,
      height: height,
    );

    final mask = List<bool>.filled(width * height, true);
    for (int i = 0; i < edges.length; i++) {
      if (edges[i] > edgeThreshold) {
        mask[i] = false; // discard boundary pixel
      }
    }

    return mask;
  }
}
