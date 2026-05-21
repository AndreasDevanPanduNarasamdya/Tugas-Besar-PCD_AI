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
  static const int maxPoints = 50000;

  final List<PointCloudPoint> _points = [];

  List<PointCloudPoint> get points => List.unmodifiable(_points);
  int get pointCount => _points.length;
  bool get isFull => _points.length >= maxPoints;

  /// Add points from a single frame
  /// depthMap: Float32List [518*518] normalized 0-1
  /// segMask: Uint8List [256*256] binary mask
  /// rgbFrame: Uint8List [518*518*3] RGB bytes
  /// cameraPose: camera transform matrix
  void addFrame({
    required Float32List depthMap,
    required Uint8List segMask,
    required Uint8List rgbFrame,
    required Matrix4 cameraPose,
    required double focalLength,
    required double cx,
    required double cy,
    int depthWidth = 518,
    int depthHeight = 518,
    int segWidth = 256,
    int segHeight = 256,
  }) {
    if (isFull) return;

    // Sample every nth pixel to stay within maxPoints
    final totalPixels = depthWidth * depthHeight;
    final step =
        (totalPixels / (maxPoints - _points.length)).ceil().clamp(1, 8);

    for (int y = 0; y < depthHeight; y += step) {
      for (int x = 0; x < depthWidth; x += step) {
        if (isFull) return;

        final depthIdx = y * depthWidth + x;
        final depth = depthMap[depthIdx];

        // Skip very near or very far points
        // if (depth < 0.01 || depth > 0.99) continue;

        // Check segmentation mask — scale coords to seg size
        final segX = (x * segWidth / depthWidth).round().clamp(0, segWidth - 1);
        final segY =
            (y * segHeight / depthHeight).round().clamp(0, segHeight - 1);
        final segIdx = segY * segWidth + segX;
        if (segMask[segIdx] == 0) continue; // background — skip

        // Unproject to 3D
        final realDepth = depth * 5.0; // scale to meters
        final px = (x - cx) * realDepth / focalLength;
        final py = (y - cy) * realDepth / focalLength;
        final pz = realDepth;

        final localPoint = Vector4(px, py, pz, 1.0);
        final worldPoint = cameraPose.transform(localPoint);

        // Get color from RGB frame
        final rgbIdx = depthIdx * 3;
        final r = rgbFrame[rgbIdx] / 255.0;
        final g = rgbFrame[rgbIdx + 1] / 255.0;
        final b = rgbFrame[rgbIdx + 2] / 255.0;

        // Estimate normal from neighboring depth values
        final normal = _estimateNormal(
          depthMap,
          x,
          y,
          depthWidth,
          depthHeight,
          focalLength,
          cx,
          cy,
        );

        _points.add(PointCloudPoint(
          position: Vector3(worldPoint.x, worldPoint.y, worldPoint.z),
          color: Vector3(r, g, b),
          normal: normal,
        ));
      }
    }
  }

  void addFrameWithMask({
    required Float32List depthMap,
    required Uint8List segMask,
    required List<bool> validMask,
    required Uint8List rgbFrame,
    required Matrix4 cameraPose,
    required double focalLength,
    required double cx,
    required double cy,
    int depthWidth = 518,
    int depthHeight = 518,
    int segWidth = 256,
    int segHeight = 256,
  }) {
    if (isFull) return;

    final totalPixels = depthWidth * depthHeight;
    final step =
        (totalPixels / (maxPoints - _points.length)).ceil().clamp(1, 8);

    for (int y = 0; y < depthHeight; y += step) {
      for (int x = 0; x < depthWidth; x += step) {
        if (isFull) return;

        final depthIdx = y * depthWidth + x;

        // ── Skip edge pixels ──────────────────────────────────
        if (!validMask[depthIdx]) continue;

        final depth = depthMap[depthIdx];
        // if (depth < 0.01 || depth > 0.99) continue;

        // ── Skip background pixels ────────────────────────────
        final segX = (x * segWidth / depthWidth).round().clamp(0, segWidth - 1);
        final segY =
            (y * segHeight / depthHeight).round().clamp(0, segHeight - 1);
        // if (segMask[segY * segWidth + segX] == 0) continue;

        // ── Unproject to 3D ───────────────────────────────────
        final realDepth = depth * 5.0;
        final px = (x - cx) * realDepth / focalLength;
        final py = (y - cy) * realDepth / focalLength;
        final pz = realDepth;

        final localPoint = Vector4(px, py, pz, 1.0);
        final worldPoint = cameraPose.transform(localPoint);

        // ── Get color ─────────────────────────────────────────
        final rgbIdx = depthIdx * 3;
        final r = rgbFrame[rgbIdx] / 255.0;
        final g = rgbFrame[rgbIdx + 1] / 255.0;
        final b = rgbFrame[rgbIdx + 2] / 255.0;

        // ── Estimate normal ───────────────────────────────────
        final normal = _estimateNormal(
          depthMap,
          x,
          y,
          depthWidth,
          depthHeight,
          focalLength,
          cx,
          cy,
        );

        _points.add(PointCloudPoint(
          position: Vector3(worldPoint.x, worldPoint.y, worldPoint.z),
          color: Vector3(r, g, b),
          normal: normal,
        ));
      }
    }
  }

  Vector3 _estimateNormal(
    Float32List depthMap,
    int x,
    int y,
    int width,
    int height,
    double focalLength,
    double cx,
    double cy,
  ) {
    // Simple cross-product normal estimation from neighbors
    Vector3 _unproject(int px, int py) {
      final d = depthMap[py * width + px] * 5.0;
      return Vector3(
        (px - cx) * d / focalLength,
        (py - cy) * d / focalLength,
        d,
      );
    }

    final xp = (x + 1).clamp(0, width - 1);
    final xm = (x - 1).clamp(0, width - 1);
    final yp = (y + 1).clamp(0, height - 1);
    final ym = (y - 1).clamp(0, height - 1);

    final dx = _unproject(xp, y) - _unproject(xm, y);
    final dy = _unproject(x, yp) - _unproject(x, ym);

    final normal = dx.cross(dy);
    if (normal.length > 0) normal.normalize();
    return normal;
  }

  void clear() {
    _points.clear();
  }

  /// Export as flat Float32List for rendering
  /// Format: x,y,z,r,g,b per point
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
