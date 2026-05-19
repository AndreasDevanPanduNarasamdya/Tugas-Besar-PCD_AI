import 'dart:typed_data';
import 'package:image/image.dart' as img;

class FramePreprocessor {
  static const int depthInputSize = 518;
  static const int segInputSize = 256;

  /// Convert raw camera YUV bytes to RGB Uint8List
  Uint8List yuv420ToRgb(
    Uint8List yPlane,
    Uint8List uPlane,
    Uint8List vPlane,
    int width,
    int height,
  ) {
    final rgb = Uint8List(width * height * 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        final yVal = yPlane[yIndex].toDouble();
        final uVal = uPlane[uvIndex].toDouble() - 128;
        final vVal = vPlane[uvIndex].toDouble() - 128;

        final r = (yVal + 1.402 * vVal).round().clamp(0, 255);
        final g =
            (yVal - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
        final b = (yVal + 1.772 * uVal).round().clamp(0, 255);

        final idx = yIndex * 3;
        rgb[idx] = r;
        rgb[idx + 1] = g;
        rgb[idx + 2] = b;
      }
    }

    return rgb;
  }

  /// Prepare frame for Depth Anything V2 (518x518 float32 normalized)
  Float32List prepareForDepth(Uint8List rgbBytes, int width, int height) {
    return _resizeAndNormalize(rgbBytes, width, height, depthInputSize);
  }

  /// Prepare frame for MediaPipe Segmentation (256x256 float32 normalized)
  Float32List prepareForSegmentation(
      Uint8List rgbBytes, int width, int height) {
    return _resizeAndNormalize(rgbBytes, width, height, segInputSize);
  }

  Float32List _resizeAndNormalize(
    Uint8List rgbBytes,
    int srcWidth,
    int srcHeight,
    int targetSize,
  ) {
    // Build image from raw RGB bytes
    final image = img.Image.fromBytes(
      width: srcWidth,
      height: srcHeight,
      bytes: rgbBytes.buffer,
      numChannels: 3,
    );

    // Resize
    final resized = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );

    // Normalize to [0, 1] float32
    final result = Float32List(targetSize * targetSize * 3);
    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = resized.getPixel(x, y);
        final idx = (y * targetSize + x) * 3;
        result[idx] = pixel.r / 255.0;
        result[idx + 1] = pixel.g / 255.0;
        result[idx + 2] = pixel.b / 255.0;
      }
    }

    return result;
  }

  /// Check if frame is too blurry to use (Laplacian variance)
  bool isFrameSharp(Uint8List rgbBytes, int width, int height) {
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    // Laplacian kernel: [0,1,0,1,-4,1,0,1,0]
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Use green channel only for speed
        final idx = (y * width + x) * 3 + 1;
        final center = rgbBytes[idx].toDouble();
        final top = rgbBytes[((y - 1) * width + x) * 3 + 1].toDouble();
        final bottom = rgbBytes[((y + 1) * width + x) * 3 + 1].toDouble();
        final left = rgbBytes[(y * width + (x - 1)) * 3 + 1].toDouble();
        final right = rgbBytes[(y * width + (x + 1)) * 3 + 1].toDouble();

        final lap = (top + bottom + left + right - 4 * center).abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return false;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    // Threshold — below 100 is considered too blurry
    return variance > 100;
  }
}
