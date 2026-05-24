import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

class PointCloudPoint {
  final Vector3 position;
  final Vector3 color;
  final Vector3 normal;

  PointCloudPoint({
    required this.position,
    required this.color,
    required this.normal,
  });
}

class PointCloudBuilder {
  static const int maxPoints = 3000; // reduced for mobile

  final List<PointCloudPoint> _points = [];

  List<PointCloudPoint> get points => List.unmodifiable(_points);
  int get pointCount => _points.length;
  bool get isFull => _points.length >= maxPoints;

  void addFrameWithMask({
    required Float32List depthMap,
    required Uint8List segMask,
    required List<bool> validMask,
    required Uint8List rgbFrame,
    required Matrix4 cameraPose,
    required double focalLength,
    required double cx,
    required double cy,
    int depthWidth = 256, // matches new smaller input size
    int depthHeight = 256,
    int segWidth = 128,
    int segHeight = 128,
  }) {
    if (isFull) return;

    final remaining = maxPoints - _points.length;
    final totalPixels = depthWidth * depthHeight;
    final step = (totalPixels / remaining).ceil().clamp(2, 16);

    for (int y = 0; y < depthHeight; y += step) {
      for (int x = 0; x < depthWidth; x += step) {
        if (isFull) return;

        final depthIdx = y * depthWidth + x;
        if (depthIdx >= depthMap.length) continue;

        // Edge filter
        if (depthIdx < validMask.length && !validMask[depthIdx]) continue;

        final depth = depthMap[depthIdx];

        // Skip flat/invalid depth
        if (depth < 0.02 || depth > 0.98) continue;

        // Seg mask check
        final segX = (x * segWidth / depthWidth).round().clamp(0, segWidth - 1);
        final segY =
            (y * segHeight / depthHeight).round().clamp(0, segHeight - 1);
        final segIdx = segY * segWidth + segX;
        if (segIdx < segMask.length && segMask[segIdx] == 0) continue;

        // Unproject
        final realDepth = 0.3 + depth * 3.0; // tighter range
        final px = (x - cx) * realDepth / focalLength;
        final py = (y - cy) * realDepth / focalLength;
        final pz = realDepth;

        final localPoint = Vector4(px, py, pz, 1.0);
        final worldPoint = cameraPose.transform(localPoint);

        // Color
        final rgbIdx = depthIdx * 3;
        if (rgbIdx + 2 >= rgbFrame.length) continue;
        final r = rgbFrame[rgbIdx] / 255.0;
        final g = rgbFrame[rgbIdx + 1] / 255.0;
        final b = rgbFrame[rgbIdx + 2] / 255.0;

        // Simplified normal — skip expensive cross product
        final normal = Vector3(0, 0, 1); // forward-facing default

        _points.add(PointCloudPoint(
          position: Vector3(worldPoint.x, worldPoint.y, worldPoint.z),
          color: Vector3(r, g, b),
          normal: normal,
        ));
      }
    }
  }

  // Keep addFrame for compatibility
  void addFrame({
    required Float32List depthMap,
    required Uint8List segMask,
    required Uint8List rgbFrame,
    required Matrix4 cameraPose,
    required double focalLength,
    required double cx,
    required double cy,
    int depthWidth = 256,
    int depthHeight = 256,
    int segWidth = 128,
    int segHeight = 128,
  }) {
    final fakeValidMask = List<bool>.filled(depthWidth * depthHeight, true);
    addFrameWithMask(
      depthMap: depthMap,
      segMask: segMask,
      validMask: fakeValidMask,
      rgbFrame: rgbFrame,
      cameraPose: cameraPose,
      focalLength: focalLength,
      cx: cx,
      cy: cy,
      depthWidth: depthWidth,
      depthHeight: depthHeight,
      segWidth: segWidth,
      segHeight: segHeight,
    );
  }

  void clear() => _points.clear();

  Float32List toFloat32List() {
    final result = Float32List(_points.length * 6);
    for (int i = 0; i < _points.length; i++) {
      final p = _points[i];
      result[i * 6 + 0] = p.position.x;
      result[i * 6 + 1] = p.position.y;
      result[i * 6 + 2] = p.position.z;
      result[i * 6 + 3] = p.color.x;
      result[i * 6 + 4] = p.color.y;
      result[i * 6 + 5] = p.color.z;
    }
    return result;
  }
}
