import 'dart:typed_data';
import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import '../config/env_config.dart';

class PointCloudPoint {
  final Vector3 position;
  final Vector3 normal;

  PointCloudPoint({
    required this.position,
    required this.normal,
  });
}

class MeshData {
  final Float32List vertices;
  final Uint32List indices;
  final Float32List normals;
  final Float32List uvs;
  final Float32List colors;

  int get vertexCount => vertices.length ~/ 3;
  int get faceCount => indices.length ~/ 3;
  int get edgeCount => (faceCount * 3) ~/ 2;
  int get triangleCount => faceCount;

  MeshData({
    required this.vertices,
    required this.indices,
    required this.normals,
    required this.uvs,
    required this.colors,
  });
}

class SpaceCarver {
  static MeshData carveAndMesh({
    required List<List<bool>> masks,
    required List<Float32List> depthMaps,
    required List<Matrix4> cameraPoses,
    required double focalLength,
    required double cx,
    required double cy,
    int maskWidth = 518,
    int maskHeight = 518,
    int voxelResolution = 64, // Used for downsampling grid size now
    double physicalSize = 1.0,
    int tRes = 60,
    int pRes = 60,
  }) {
    // ── Step 1: DEPTH UNPROJECTION ───────────────────────────────────────────
    // We shoot laser beams out of every camera to build the true physical shape
    final rawPoints = _unprojectDepth(
      masks: masks,
      depthMaps: depthMaps,
      cameraPoses: cameraPoses,
      focalLength: focalLength,
      cx: cx,
      cy: cy,
      width: maskWidth,
      height: maskHeight,
    );

    if (rawPoints.isEmpty) {
      return MeshData(
        vertices: Float32List(0),
        indices: Uint32List(0),
        normals: Float32List(0),
        uvs: Float32List(0),
        colors: Float32List(0),
      );
    }

    // ── Step 2: Voxel Downsampling ───────────────────────────────────────────
    // Fusing 8 photos generates millions of points. We compress them into a
    // clean grid to keep the Flutter engine running at 60 FPS.
    final double gridSize = physicalSize / voxelResolution;
    final filteredPoints = _voxelFilter(rawPoints, gridSize);

    // ── Step 3: Normal Estimation ────────────────────────────────────────────
    final withNormals = _estimateNormals(filteredPoints, gridSize * 2.0);

    // ── Step 4: Surface Splatting ────────────────────────────────────────────
    return _generateSplatMesh(withNormals, gridSize * 1.5);
  }

  // ── Private: Unproject 2.5D Depth to 3D Space ─────────────────────────────

  static List<PointCloudPoint> _unprojectDepth({
    // <-- Now returns PointCloudPoint!
    required List<List<bool>> masks,
    required List<Float32List> depthMaps,
    required List<Matrix4> cameraPoses,
    required List<Uint8List> rgbFrames, // <-- NEW: We pass the photos in!
    required double focalLength,
    required double cx,
    required double cy,
    required int width,
    required int height,
  }) {
    final points = <PointCloudPoint>[];
    const double nearPlane = 0.3;
    const double depthRange = 3.0;

    for (int cam = 0; cam < depthMaps.length; cam++) {
      final pose = cameraPoses[cam];
      final depthMap = depthMaps[cam];
      final mask = masks[cam];
      final rgb = rgbFrames[cam];

      for (int y = 0; y < height; y += 3) {
        for (int x = 0; x < width; x += 3) {
          final idx = y * width + x;

          if (!mask[idx]) continue;

          // 1. Calculate 3D Position
          final rawDepth = depthMap[idx];
          final metricZ = nearPlane + (1.0 - rawDepth) * depthRange;
          final localPoint = Vector3((x - cx) * metricZ / focalLength,
              (y - cy) * metricZ / focalLength, metricZ);
          final worldPoint = pose.transform3(localPoint);

          // 2. Grab the EXACT pixel color from the photo!
          final colorIdx = idx * 3; // Assuming RGB byte order
          final r = rgb[colorIdx] / 255.0;
          final g = rgb[colorIdx + 1] / 255.0;
          final b = rgb[colorIdx + 2] / 255.0;

          points.add(PointCloudPoint(
              position: worldPoint,
              color: Vector3(r, g, b), // Color baked instantly!
              normal: Vector3(0, 0, 1)));
        }
      }
    }
    return points;
  }
  // ── Private: Voxel Grid Downsampling ──────────────────────────────────────

  static List<Vector3> _voxelFilter(List<Vector3> points, double cellSize) {
    final Map<String, List<Vector3>> grid = {};

    for (final p in points) {
      final gx = (p.x / cellSize).floor();
      final gy = (p.y / cellSize).floor();
      final gz = (p.z / cellSize).floor();
      final key = '$gx,$gy,$gz';
      grid.putIfAbsent(key, () => []).add(p);
    }

    // Average the points in each cell for a smooth surface
    final filtered = <Vector3>[];
    for (final cellPoints in grid.values) {
      Vector3 sum = Vector3.zero();
      for (final p in cellPoints) sum += p;
      filtered.add(sum / cellPoints.length.toDouble());
    }
    return filtered;
  }

  // ── Private: Normal Estimation ────────────────────────────────────────────

  static List<PointCloudPoint> _estimateNormals(
      List<Vector3> points, double searchRadius) {
    // (We reuse your existing fast voxel grid normal estimator here)
    final Map<String, List<int>> grid = {};
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final gx = (p.x / searchRadius).floor();
      final gy = (p.y / searchRadius).floor();
      final gz = (p.z / searchRadius).floor();
      grid.putIfAbsent('$gx,$gy,$gz', () => []).add(i);
    }

    final result = <PointCloudPoint>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final neighbors = <Vector3>[];
      final gx = (p.x / searchRadius).floor();
      final gy = (p.y / searchRadius).floor();
      final gz = (p.z / searchRadius).floor();

      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          for (int dz = -1; dz <= 1; dz++) {
            final cell = grid['${gx + dx},${gy + dy},${gz + dz}'];
            if (cell != null) {
              for (final j in cell) if (j != i) neighbors.add(points[j]);
            }
          }
        }
      }

      Vector3 normal = Vector3(0, 0, 1);
      if (neighbors.length >= 3) {
        final centroid = neighbors.fold(Vector3.zero(), (acc, v) => acc + v) /
            neighbors.length.toDouble();
        double cxx = 0, cxy = 0, cxz = 0, cyy = 0, cyz = 0, czz = 0;
        for (final n in neighbors) {
          final d = n - centroid;
          cxx += d.x * d.x;
          cxy += d.x * d.y;
          cxz += d.x * d.z;
          cyy += d.y * d.y;
          cyz += d.y * d.z;
          czz += d.z * d.z;
        }
        final axis1 = Vector3(cxx, cxy, cxz)..normalize();
        final axis2 = Vector3(cxy, cyy, cyz)..normalize();
        normal = axis1.cross(axis2);
        if (normal.length < 1e-6) normal = Vector3(0, 0, 1);
        normal.normalize();
        if (normal.dot(p) > 0) normal = -normal; // Face outward
      }

      result.add(PointCloudPoint(position: p, normal: normal));
    }
    return result;
  }

  // ── Private: Surface Splatting ────────────────────────────────────────────

  static MeshData _generateSplatMesh(
      List<PointCloudPoint> points, double splatSize) {
    // (This remains exactly the same as your previous Splatting engine)
    final int vCount = points.length * 4;
    final int iCount = points.length * 6;
    final Float32List vertices = Float32List(vCount * 3);
    final Float32List normals = Float32List(vCount * 3);
    final Float32List uvs = Float32List(vCount * 2);
    final Uint32List indices = Uint32List(iCount);

    int vIdx = 0;
    int iIdx = 0;
    final double halfSize = splatSize / 2.0;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final pos = p.position;
      final norm = p.normal;

      Vector3 tangent;
      if (norm.x.abs() > 0.9)
        tangent = Vector3(0, 1, 0).cross(norm)..normalize();
      else
        tangent = Vector3(1, 0, 0).cross(norm)..normalize();

      final bitangent = norm.cross(tangent)..normalize();
      tangent.scale(halfSize);
      bitangent.scale(halfSize);

      final v0 = pos - tangent - bitangent;
      final v1 = pos + tangent - bitangent;
      final v2 = pos + tangent + bitangent;
      final v3 = pos - tangent + bitangent;
      final baseV = i * 4;

      vertices[vIdx * 3] = v0.x;
      vertices[vIdx * 3 + 1] = v0.y;
      vertices[vIdx * 3 + 2] = v0.z;
      vertices[(vIdx + 1) * 3] = v1.x;
      vertices[(vIdx + 1) * 3 + 1] = v1.y;
      vertices[(vIdx + 1) * 3 + 2] = v1.z;
      vertices[(vIdx + 2) * 3] = v2.x;
      vertices[(vIdx + 2) * 3 + 1] = v2.y;
      vertices[(vIdx + 2) * 3 + 2] = v2.z;
      vertices[(vIdx + 3) * 3] = v3.x;
      vertices[(vIdx + 3) * 3 + 1] = v3.y;
      vertices[(vIdx + 3) * 3 + 2] = v3.z;

      for (int j = 0; j < 4; j++) {
        normals[(vIdx + j) * 3] = norm.x;
        normals[(vIdx + j) * 3 + 1] = norm.y;
        normals[(vIdx + j) * 3 + 2] = norm.z;
      }

      uvs[vIdx * 2] = 0;
      uvs[vIdx * 2 + 1] = 0;
      uvs[(vIdx + 1) * 2] = 1;
      uvs[(vIdx + 1) * 2 + 1] = 0;
      uvs[(vIdx + 2) * 2] = 1;
      uvs[(vIdx + 2) * 2 + 1] = 1;
      uvs[(vIdx + 3) * 2] = 0;
      uvs[(vIdx + 3) * 2 + 1] = 1;

      indices[iIdx] = baseV;
      indices[iIdx + 1] = baseV + 1;
      indices[iIdx + 2] = baseV + 2;
      indices[iIdx + 3] = baseV;
      indices[iIdx + 4] = baseV + 2;
      indices[iIdx + 5] = baseV + 3;

      vIdx += 4;
      iIdx += 6;
    }

    return MeshData(
      vertices: vertices,
      indices: indices,
      normals: normals,
      uvs: uvs,
      colors: Float32List(vCount * 3),
    );
  }
}
