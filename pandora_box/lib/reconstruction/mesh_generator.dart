import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'point_cloud_builder.dart';

class Mesh {
  final Float32List vertices; // x,y,z per vertex
  final Uint32List indices; // triangles
  final Float32List normals; // x,y,z per vertex
  final Float32List uvs; // u,v per vertex
  final Float32List colors; // r,g,b per vertex

  int get vertexCount => vertices.length ~/ 3;
  int get faceCount => indices.length ~/ 3;
  int get edgeCount => (faceCount * 3) ~/ 2;
  int get triangleCount => faceCount;

  Mesh({
    required this.vertices,
    required this.indices,
    required this.normals,
    required this.uvs,
    required this.colors,
  });
}

class MeshGenerator {
  /// Generate mesh from point cloud using simple voxel-based approach
  Mesh generate(List<PointCloudPoint> points) {
    if (points.isEmpty) {
      return Mesh(
        vertices: Float32List(0),
        indices: Uint32List(0),
        normals: Float32List(0),
        uvs: Float32List(0),
        colors: Float32List(0),
      );
    }

    // Step 1: Compute bounding box
    final bbox = _computeBoundingBox(points);

    // Step 2: Generate UV coordinates
    final uvs = _generateUVs(points, bbox);

    // Step 3: Build vertex buffers
    final vertices = Float32List(points.length * 3);
    final normals = Float32List(points.length * 3);
    final colors = Float32List(points.length * 3);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      vertices[i * 3 + 0] = p.position.x;
      vertices[i * 3 + 1] = p.position.y;
      vertices[i * 3 + 2] = p.position.z;
      normals[i * 3 + 0] = p.normal.x;
      normals[i * 3 + 1] = p.normal.y;
      normals[i * 3 + 2] = p.normal.z;
      colors[i * 3 + 0] = p.color.x;
      colors[i * 3 + 1] = p.color.y;
      colors[i * 3 + 2] = p.color.z;
    }

    // Step 4: Generate triangles via Delaunay-like nearest neighbor
    final indices = _generateTriangles(points, bbox);

    // Step 5: Remove degenerate faces
    final cleanIndices = _removeDegenerateFaces(indices, vertices);

    return Mesh(
      vertices: vertices,
      indices: cleanIndices,
      normals: normals,
      uvs: uvs,
      colors: colors,
    );
  }

  _BoundingBox _computeBoundingBox(List<PointCloudPoint> points) {
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    double minZ = double.infinity, maxZ = double.negativeInfinity;

    for (final p in points) {
      if (p.position.x < minX) minX = p.position.x;
      if (p.position.x > maxX) maxX = p.position.x;
      if (p.position.y < minY) minY = p.position.y;
      if (p.position.y > maxY) maxY = p.position.y;
      if (p.position.z < minZ) minZ = p.position.z;
      if (p.position.z > maxZ) maxZ = p.position.z;
    }

    return _BoundingBox(minX, maxX, minY, maxY, minZ, maxZ);
  }

  Float32List _generateUVs(List<PointCloudPoint> points, _BoundingBox bbox) {
    final uvs = Float32List(points.length * 2);

    final width = bbox.maxX - bbox.minX;
    final depth = bbox.maxZ - bbox.minZ;
    final height = bbox.maxY - bbox.minY;

    // Auto-detect cylindrical vs box mapping
    final isCylindrical =
        height > (width * 1.5) && (width - depth).abs() < width * 0.3;

    for (int i = 0; i < points.length; i++) {
      final p = points[i].position;
      double u, v;

      if (isCylindrical) {
        // Cylindrical mapping
        final cx = (bbox.minX + bbox.maxX) / 2;
        final cz = (bbox.minZ + bbox.maxZ) / 2;
        u = (atan2(p.z - cz, p.x - cx) / (2 * pi) + 0.5);
        v = (p.y - bbox.minY) / height;
      } else {
        // Box mapping based on dominant normal direction
        final normal = points[i].normal;
        final ax = normal.x.abs();
        final ay = normal.y.abs();
        final az = normal.z.abs();

        if (ay >= ax && ay >= az) {
          // Top/bottom face
          u = (p.x - bbox.minX) / width;
          v = (p.z - bbox.minZ) / depth;
        } else if (ax >= ay && ax >= az) {
          // Left/right face
          u = (p.z - bbox.minZ) / depth;
          v = (p.y - bbox.minY) / height;
        } else {
          // Front/back face
          u = (p.x - bbox.minX) / width;
          v = (p.y - bbox.minY) / height;
        }
      }

      uvs[i * 2 + 0] = u.clamp(0.0, 1.0);
      uvs[i * 2 + 1] = v.clamp(0.0, 1.0);
    }

    return uvs;
  }

  Uint32List _generateTriangles(
      List<PointCloudPoint> points, _BoundingBox bbox) {
    // Simple grid-based triangulation
    // Works well for structured point clouds from depth cameras
    final List<int> indices = [];
    final int n = points.length;

    // Build spatial grid for neighbor lookup
    final int gridSize = 20;
    final Map<int, List<int>> grid = {};

    final rangeX = bbox.maxX - bbox.minX;
    final rangeY = bbox.maxY - bbox.minY;
    final rangeZ = bbox.maxZ - bbox.minZ;

    for (int i = 0; i < n; i++) {
      final p = points[i].position;
      final gx = ((p.x - bbox.minX) / rangeX * (gridSize - 1)).round();
      final gy = ((p.y - bbox.minY) / rangeY * (gridSize - 1)).round();
      final key = gy * gridSize + gx;
      grid.putIfAbsent(key, () => []).add(i);
    }

    // Connect nearby points into triangles
    final double maxEdgeLen = (rangeX + rangeY + rangeZ) / (gridSize * 1.5);

    for (int i = 0; i < n; i++) {
      final p = points[i].position;
      final gx = ((p.x - bbox.minX) / rangeX * (gridSize - 1)).round();
      final gy = ((p.y - bbox.minY) / rangeY * (gridSize - 1)).round();

      // Check neighboring cells
      for (int dy = 0; dy <= 1; dy++) {
        for (int dx = 0; dx <= 1; dx++) {
          final nx = gx + dx;
          final ny = gy + dy;
          if (nx >= gridSize || ny >= gridSize) continue;

          final key = ny * gridSize + nx;
          final neighbors = grid[key];
          if (neighbors == null || neighbors.length < 2) continue;

          for (int a = 0; a < neighbors.length - 1; a++) {
            final j = neighbors[a];
            final k = neighbors[a + 1];
            if (j == i || k == i) continue;

            // Check edge lengths
            final dij = (points[i].position - points[j].position).length;
            final djk = (points[j].position - points[k].position).length;
            final dik = (points[i].position - points[k].position).length;

            if (dij > maxEdgeLen || djk > maxEdgeLen || dik > maxEdgeLen)
              continue;

            indices.addAll([i, j, k]);
          }
        }
      }
    }

    return Uint32List.fromList(indices);
  }

  Uint32List _removeDegenerateFaces(Uint32List indices, Float32List vertices) {
    final List<int> clean = [];

    for (int i = 0; i < indices.length; i += 3) {
      final a = indices[i];
      final b = indices[i + 1];
      final c = indices[i + 2];

      if (a == b || b == c || a == c) continue;

      final va =
          Vector3(vertices[a * 3], vertices[a * 3 + 1], vertices[a * 3 + 2]);
      final vb =
          Vector3(vertices[b * 3], vertices[b * 3 + 1], vertices[b * 3 + 2]);
      final vc =
          Vector3(vertices[c * 3], vertices[c * 3 + 1], vertices[c * 3 + 2]);

      final area = (vb - va).cross(vc - va).length / 2;
      if (area < 1e-8) continue;

      clean.addAll([a, b, c]);
    }

    return Uint32List.fromList(clean);
  }
}

class _BoundingBox {
  final double minX, maxX, minY, maxY, minZ, maxZ;
  _BoundingBox(
      this.minX, this.maxX, this.minY, this.maxY, this.minZ, this.maxZ);
}
