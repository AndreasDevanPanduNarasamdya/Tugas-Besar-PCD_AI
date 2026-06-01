// import 'dart:typed_data';
// import 'package:vector_math/vector_math.dart';
// import '../config/env_config.dart';

// class PointCloudPoint {
//   final Vector3 position;
//   final Vector3 color;
//   final Vector3 normal;

//   PointCloudPoint({
//     required this.position,
//     required this.color,
//     required this.normal,
//   });
// }

// class PointCloudBuilder {
//   int get _maxPoints => EnvConfig.pointCloudMaxPoints;

//   final List<PointCloudPoint> _points = [];

//   List<PointCloudPoint> get points => List.unmodifiable(_points);
//   int get pointCount => _points.length;
//   bool get isFull => _points.length >= _maxPoints;

//   void addFrameWithMask({
//     required Float32List depthMap,
//     required List<bool> validMask, // <-- This now contains our perfect cutout!
//     required Uint8List rgbFrame,
//     required Matrix4 cameraPose,
//     required double focalLength,
//     required double cx,
//     required double cy,
//     int depthWidth = 518,
//     int depthHeight = 518,
//   }) {
//     if (isFull) return;

//     final remaining = _maxPoints - _points.length;
//     final totalPixels = depthWidth * depthHeight;
//     final step = (totalPixels / remaining).ceil().clamp(2, 16);

//     for (int y = 0; y < depthHeight; y += step) {
//       for (int x = 0; x < depthWidth; x += step) {
//         if (isFull) return;

//         final depthIdx = y * depthWidth + x;
//         if (depthIdx >= depthMap.length) continue;

//         // ── 1. THE ONLY CHECK WE NEED ────────────────────────────────────────
//         // If the ObjectSegmenter flagged this as background or an edge, drop it.
//         if (depthIdx < validMask.length && !validMask[depthIdx]) continue;

//         final depth = depthMap[depthIdx];
//         if (depth < 0.02 || depth > 0.98) continue; // Safety limits

//         // ── 2. UNPROJECT TO 3D ───────────────────────────────────────────────
//         final realDepth = EnvConfig.cameraZOffset + (1.0 - depth) * 3.0;
//         final px = (x - cx) * realDepth / focalLength;
//         final py = (y - cy) * realDepth / focalLength;
//         final pz = realDepth;

//         final worldPoint = cameraPose.transform(Vector4(px, py, pz, 1.0));

//         // Pull Color
//         final rgbIdx = depthIdx * 3;
//         if (rgbIdx + 2 >= rgbFrame.length) continue;
//         final r = rgbFrame[rgbIdx] / 255.0;
//         final g = rgbFrame[rgbIdx + 1] / 255.0;
//         final b = rgbFrame[rgbIdx + 2] / 255.0;

//         _points.add(PointCloudPoint(
//           position: Vector3(worldPoint.x, worldPoint.y, worldPoint.z),
//           color: Vector3(r, g, b),
//           normal: Vector3(0, 0, 1),
//         ));
//       }
//     }
//   }

//   void clear() => _points.clear();

//   Float32List toFloat32List() {
//     final result = Float32List(_points.length * 6);
//     for (int i = 0; i < _points.length; i++) {
//       final p = _points[i];
//       result[i * 6 + 0] = p.position.x;
//       result[i * 6 + 1] = p.position.y;
//       result[i * 6 + 2] = p.position.z;
//       result[i * 6 + 3] = p.color.x;
//       result[i * 6 + 4] = p.color.y;
//       result[i * 6 + 5] = p.color.z;
//     }
//     return result;
//   }
// }
