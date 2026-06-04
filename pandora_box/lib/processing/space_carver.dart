import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

class PointCloudPoint {
  final Vector3 position;
  Vector3 normal; // Mutable so we can update it during estimation
  final Vector3 color;

  PointCloudPoint({
    required this.position,
    required this.normal,
    required this.color,
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
    required List<Float32List> depthMaps, // Kept so scan_bloc doesn't break
    required List<Matrix4> cameraPoses,
    required List<Uint8List> rgbFrames,
    required double focalLength,
    required double cx,
    required double cy,
    int maskWidth = 518,
    int maskHeight = 518,
    int voxelResolution = 64,
    double physicalSize = 1.0,
  }) {
    // ── Step 1: VISUAL HULL CARVING (The Cylinder Fix) ──
    final carvedPoints = _carve(
      masks: masks,
      cameraPoses: cameraPoses,
      rgbFrames: rgbFrames,
      focalLength: focalLength,
      cx: cx,
      cy: cy,
      width: maskWidth,
      height: maskHeight,
      voxelResolution: voxelResolution,
      physicalSize: physicalSize,
    );

    if (carvedPoints.isEmpty) {
      return MeshData(
        vertices: Float32List(0),
        indices: Uint32List(0),
        normals: Float32List(0),
        uvs: Float32List(0),
        colors: Float32List(0),
      );
    }

    // ── Step 2: Normal Estimation ──
    final double gridSize = physicalSize / voxelResolution;
    _estimateNormals(carvedPoints, gridSize * 2.0);

    // ── Step 3: Surface Splatting ──
    return _generateSplatMesh(carvedPoints, gridSize * 1.5);
  }

  // ── Private: True 3D Visual Hull Carving ──

  static List<PointCloudPoint> _carve({
    required List<List<bool>> masks,
    required List<Matrix4> cameraPoses,
    required List<Uint8List> rgbFrames,
    required double focalLength,
    required double cx,
    required double cy,
    required int width,
    required int height,
    required int voxelResolution,
    required double physicalSize,
  }) {
    final result = <PointCloudPoint>[];
    final halfSize = physicalSize / 2.0;
    final stepSize = physicalSize / voxelResolution;

    // THE ARCHITECT'S GATE: The maximum radius of our starting cylinder
    final double radiusSq = halfSize * halfSize;
    final inversePoses =
        cameraPoses.map((p) => Matrix4.copy(p)..invert()).toList();

    for (int ix = 0; ix < voxelResolution; ix++) {
      final x = -halfSize + ix * stepSize;

      for (int iz = 0; iz < voxelResolution; iz++) {
        final z = -halfSize + iz * stepSize;

        // 1. IF OUTSIDE THE CYLINDER, VAPORIZE IMMEDIATELY
        if ((x * x) + (z * z) > radiusSq) continue;

        for (int iy = 0; iy < voxelResolution; iy++) {
          final y = -halfSize + iy * stepSize;
          bool survives = true;

          double rSum = 0, gSum = 0, bSum = 0;
          int colorCount = 0;

          // 2. THE LASER CUTTER
          for (int cam = 0; cam < masks.length; cam++) {
            final local = inversePoses[cam].transform(Vector4(x, y, z, 1.0));

            if (local.z <= 0.0) {
              survives = false;
              break;
            }

            final u = ((local.x * focalLength) / local.z + cx).round();
            final v = ((local.y * focalLength) / local.z + cy).round();

            if (u < 0 || u >= width || v < 0 || v >= height) {
              survives = false;
              break;
            }

            final pixelIdx = v * width + u;
            if (!masks[cam][pixelIdx]) {
              survives = false;
              break; // Shaved off by the silhouette!
            }

            // 3. BAKE THE COLOR
            final rgb = rgbFrames[cam];
            final colorIdx = pixelIdx * 3;
            if (colorIdx + 2 < rgb.length) {
              rSum += rgb[colorIdx] / 255.0;
              gSum += rgb[colorIdx + 1] / 255.0;
              bSum += rgb[colorIdx + 2] / 255.0;
              colorCount++;
            }
          }

          if (survives) {
            final avgColor = colorCount > 0
                ? Vector3(
                    rSum / colorCount, gSum / colorCount, bSum / colorCount)
                : Vector3(0.5, 0.5, 0.5);

            result.add(PointCloudPoint(
              position: Vector3(x, y, z),
              normal: Vector3(0, 0, 1),
              color: avgColor,
            ));
          }
        }
      }
    }
    return result;
  }

  // ── Private: Normal Estimation ──

  static void _estimateNormals(
      List<PointCloudPoint> points, double searchRadius) {
    final Map<String, List<int>> grid = {};
    for (int i = 0; i < points.length; i++) {
      final p = points[i].position;
      final gx = (p.x / searchRadius).floor();
      final gy = (p.y / searchRadius).floor();
      final gz = (p.z / searchRadius).floor();
      grid.putIfAbsent('$gx,$gy,$gz', () => []).add(i);
    }

    for (int i = 0; i < points.length; i++) {
      final p = points[i].position;
      final neighbors = <Vector3>[];
      final gx = (p.x / searchRadius).floor();
      final gy = (p.y / searchRadius).floor();
      final gz = (p.z / searchRadius).floor();

      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          for (int dz = -1; dz <= 1; dz++) {
            final cell = grid['${gx + dx},${gy + dy},${gz + dz}'];
            if (cell != null) {
              for (final j in cell)
                if (j != i) neighbors.add(points[j].position);
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
        if (normal.dot(p) > 0) normal = -normal;
      }
      points[i].normal = normal;
    }
  }

  // ── Private: Surface Splatting ──

  static MeshData _generateSplatMesh(
      List<PointCloudPoint> points, double splatSize) {
    final int vCount = points.length * 4;
    final int iCount = points.length * 6;
    final Float32List vertices = Float32List(vCount * 3);
    final Float32List normals = Float32List(vCount * 3);
    final Float32List uvs = Float32List(vCount * 2);
    final Float32List colors = Float32List(vCount * 3);
    final Uint32List indices = Uint32List(iCount);

    int vIdx = 0;
    int iIdx = 0;
    final double halfSize = splatSize / 2.0;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final pos = p.position;
      final norm = p.normal;
      final color = p.color;

      Vector3 tangent = (norm.x.abs() > 0.9)
          ? (Vector3(0, 1, 0).cross(norm)..normalize())
          : (Vector3(1, 0, 0).cross(norm)..normalize());

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
        // Apply baked colors to the splat corners
        colors[(vIdx + j) * 3] = color.x;
        colors[(vIdx + j) * 3 + 1] = color.y;
        colors[(vIdx + j) * 3 + 2] = color.z;
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
      colors: colors,
    );
  }
}
