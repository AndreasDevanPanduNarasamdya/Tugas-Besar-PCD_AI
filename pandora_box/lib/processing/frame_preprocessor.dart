import 'dart:typed_data';
import 'package:image/image.dart' as img;

class FramePreprocessor {
  // Reduced input sizes for speed
  static const int depthInputSize = 256; // was 518 — halved
  static const int segInputSize = 128; // was 256 — halved

  // Reusable buffers to avoid allocation
  static final _depthBuffer = Float32List(256 * 256 * 3);
  static final _segBuffer = Float32List(128 * 128 * 3);

  Uint8List yuv420ToRgb(
    Uint8List yPlane,
    Uint8List uPlane,
    Uint8List vPlane,
    int width,
    int height, {
    int subsample = 2, // process every 2nd pixel for speed
  }) {
    final outW = width ~/ subsample;
    final outH = height ~/ subsample;
    final rgb = Uint8List(outW * outH * 3);

    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        final srcX = x * subsample;
        final srcY = y * subsample;

        final yIndex = srcY * width + srcX;
        final uvIndex = (srcY ~/ 2) * (width ~/ 2) + (srcX ~/ 2);

        if (yIndex >= yPlane.length) continue;
        if (uvIndex >= uPlane.length || uvIndex >= vPlane.length) continue;

        final yVal = yPlane[yIndex].toDouble();
        final uVal = uPlane[uvIndex].toDouble() - 128;
        final vVal = vPlane[uvIndex].toDouble() - 128;

        final r = (yVal + 1.402 * vVal).round().clamp(0, 255);
        final g =
            (yVal - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
        final b = (yVal + 1.772 * uVal).round().clamp(0, 255);

        final idx = (y * outW + x) * 3;
        rgb[idx] = r;
        rgb[idx + 1] = g;
        rgb[idx + 2] = b;
      }
    }

    return rgb;
  }

  /// Returns (rgb bytes, actual width, actual height)
  (Uint8List, int, int) yuv420ToRgbWithSize(
    Uint8List yPlane,
    Uint8List uPlane,
    Uint8List vPlane,
    int width,
    int height,
  ) {
    const subsample = 2;
    final rgb = yuv420ToRgb(yPlane, uPlane, vPlane, width, height,
        subsample: subsample);
    return (rgb, width ~/ subsample, height ~/ subsample);
  }

  Float32List prepareForDepth(Uint8List rgbBytes, int width, int height) {
    return _resizeAndNormalize(
        rgbBytes, width, height, depthInputSize, _depthBuffer);
  }

  Float32List prepareForSegmentation(
      Uint8List rgbBytes, int width, int height) {
    return _resizeAndNormalize(
        rgbBytes, width, height, segInputSize, _segBuffer);
  }

  Float32List _resizeAndNormalize(
    Uint8List rgbBytes,
    int srcWidth,
    int srcHeight,
    int targetSize,
    Float32List buffer,
  ) {
    // ── FIX: specify channel order explicitly ──────────────────
    final image = img.Image.fromBytes(
      width: srcWidth,
      height: srcHeight,
      bytes: rgbBytes.buffer,
      numChannels: 3,
      order: img.ChannelOrder.rgb, // ← THIS WAS THE BUG
    );

    final resized = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.nearest, // faster than linear
    );

    // Write into reusable buffer
    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = resized.getPixel(x, y);
        final idx = (y * targetSize + x) * 3;
        buffer[idx] = pixel.r / 255.0;
        buffer[idx + 1] = pixel.g / 255.0;
        buffer[idx + 2] = pixel.b / 255.0;
      }
    }

    return buffer;
  }

  bool isFrameSharp(Uint8List rgbBytes, int width, int height) {
    double sumSq = 0;
    double sum = 0;
    int count = 0;

    // Sample every 4th pixel for speed
    for (int y = 1; y < height - 1; y += 4) {
      for (int x = 1; x < width - 1; x += 4) {
        final idx = (y * width + x) * 3 + 1;
        if (idx + 1 >= rgbBytes.length) continue;
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
    return variance > 50; // lower threshold since we're subsampling
  }
}
