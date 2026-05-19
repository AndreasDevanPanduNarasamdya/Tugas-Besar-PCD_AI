import 'dart:typed_data';

class MedianFilter {
  /// Apply median filter to depth map
  /// Removes salt-and-pepper noise spikes
  /// More effective than mean blur for outlier removal
  static Float32List apply({
    required Float32List depthMap,
    required int width,
    required int height,
    int radius = 1, // radius=1 means 3x3 kernel
  }) {
    final output = Float32List(width * height);
    final kernelSize = (2 * radius + 1) * (2 * radius + 1);
    final window = List<double>.filled(kernelSize, 0.0);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final nx = (x + dx).clamp(0, width - 1);
            final ny = (y + dy).clamp(0, height - 1);
            window[count++] = depthMap[ny * width + nx];
          }
        }

        // Sort and pick median
        final sorted = window.sublist(0, count)..sort();
        output[y * width + x] = sorted[count ~/ 2];
      }
    }

    return output;
  }

  /// Apply median filter to a segmentation mask (Uint8List)
  static Uint8List applyToMask({
    required Uint8List mask,
    required int width,
    required int height,
    int radius = 1,
  }) {
    final output = Uint8List(width * height);
    final kernelSize = (2 * radius + 1) * (2 * radius + 1);
    final window = List<int>.filled(kernelSize, 0);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final nx = (x + dx).clamp(0, width - 1);
            final ny = (y + dy).clamp(0, height - 1);
            window[count++] = mask[ny * width + nx];
          }
        }

        final sorted = window.sublist(0, count)..sort();
        output[y * width + x] = sorted[count ~/ 2];
      }
    }

    return output;
  }
}
