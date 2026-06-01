import 'dart:typed_data';
import 'dart:math';
import 'package:vector_math/vector_math.dart';
import '../processing/space_carver.dart';

class UVMapper {
  /// Auto-detect mapping type and generate UVs
  static Float32List generate({
    required List<PointCloudPoint> points,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double minZ,
    required double maxZ,
  }) {
    final width = maxX - minX;
    final depth = maxZ - minZ;
    final height = maxY - minY;

    final isCylindrical = _isCylindrical(width, depth, height);

    final uvs = Float32List(points.length * 2);

    for (int i = 0; i < points.length; i++) {
      final p = points[i].position;
      double u, v;

      if (isCylindrical) {
        final cx = (minX + maxX) / 2;
        final cz = (minZ + maxZ) / 2;
        u = (atan2(p.z - cz, p.x - cx) / (2 * pi)) + 0.5;
        v = height > 0 ? (p.y - minY) / height : 0.0;
      } else {
        final result = _boxMap(
          p,
          points[i].normal,
          minX,
          maxX,
          minY,
          maxY,
          minZ,
          maxZ,
          width,
          depth,
          height,
        );
        u = result[0];
        v = result[1];
      }

      uvs[i * 2] = u.clamp(0.0, 1.0);
      uvs[i * 2 + 1] = v.clamp(0.0, 1.0);
    }

    return uvs;
  }

  static bool _isCylindrical(double width, double depth, double height) {
    if (width <= 0 || depth <= 0 || height <= 0) return false;
    final isTall = height > width * 1.5;
    final isRound = (width - depth).abs() < width * 0.3;
    return isTall && isRound;
  }

  static List<double> _boxMap(
    Vector3 p,
    Vector3 normal,
    double minX,
    double maxX,
    double minY,
    double maxY,
    double minZ,
    double maxZ,
    double width,
    double depth,
    double height,
  ) {
    final ax = normal.x.abs();
    final ay = normal.y.abs();
    final az = normal.z.abs();

    double u, v;

    if (ay >= ax && ay >= az) {
      // Top or bottom face
      u = width > 0 ? (p.x - minX) / width : 0.0;
      v = depth > 0 ? (p.z - minZ) / depth : 0.0;
    } else if (ax >= ay && ax >= az) {
      // Left or right face
      u = depth > 0 ? (p.z - minZ) / depth : 0.0;
      v = height > 0 ? (p.y - minY) / height : 0.0;
    } else {
      // Front or back face
      u = width > 0 ? (p.x - minX) / width : 0.0;
      v = height > 0 ? (p.y - minY) / height : 0.0;
    }

    return [u, v];
  }
}
