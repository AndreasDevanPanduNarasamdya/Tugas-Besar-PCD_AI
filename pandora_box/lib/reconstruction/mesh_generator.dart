import 'dart:typed_data';
import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

import '../processing/space_carver.dart'; // <-- THIS IS THE ONLY FIX!

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

class MeshGenerator {
  MeshData generate(List<PointCloudPoint> points, int tRes, int pRes) {
    if (points.isEmpty) {
      return MeshData(
        vertices: Float32List(0),
        indices: Uint32List(0),
        normals: Float32List(0),
        uvs: Float32List(0),
        colors: Float32List(0),
      );
    }

    // 1. Center of Mass
    Vector3 center = Vector3.zero();
    for (final p in points) center += p.position;
    center.scale(1.0 / points.length);

    // 2. Setup 2D Spherical Grids
    List<List<double>> radii =
        List.generate(tRes, (_) => List.filled(pRes, 0.0));
    List<List<Vector3>> colors =
        List.generate(tRes, (_) => List.filled(pRes, Vector3.zero()));
    List<List<int>> counts = List.generate(tRes, (_) => List.filled(pRes, 0));

    // 3. Map Point Cloud to Grid
    for (final p in points) {
      Vector3 dir = p.position - center;
      double r = dir.length;
      if (r == 0) continue;

      double theta = math.atan2(dir.z, dir.x);
      if (theta < 0) theta += 2 * math.pi;

      // Calculate phi (0 to pi)
      double phi = math.acos((dir.y / r).clamp(-1.0, 1.0));

      int t = ((theta / (2 * math.pi)) * tRes).floor().clamp(0, tRes - 1);
      int ph = ((phi / math.pi) * pRes).floor().clamp(0, pRes - 1);

      radii[t][ph] = math.max(radii[t][ph], r); // Keep outermost boundary
      colors[t][ph] += p.color;
      counts[t][ph]++;
    }

    // Average colors in populated cells
    for (int t = 0; t < tRes; t++) {
      for (int p = 0; p < pRes; p++) {
        if (counts[t][p] > 0) {
          colors[t][p].scale(1.0 / counts[t][p]);
        }
      }
    }

    // 4. THE FIX: Dilation Gap-Fill Algorithm
    // This bleeds the radius outward to fill any empty null cells
    // ensuring a 100% watertight mesh.
    bool hasZeros = true;
    int safety = 0;
    while (hasZeros && safety < 100) {
      hasZeros = false;
      safety++;

      List<List<double>> newRadii =
          List.generate(tRes, (t) => List.from(radii[t]));
      List<List<Vector3>> newColors =
          List.generate(tRes, (t) => List.from(colors[t]));

      for (int t = 0; t < tRes; t++) {
        for (int p = 0; p < pRes; p++) {
          if (radii[t][p] == 0.0) {
            double sumR = 0;
            Vector3 sumC = Vector3.zero();
            int n = 0;

            // Check Left
            int tL = (t - 1) % tRes;
            if (tL < 0) tL += tRes;
            if (radii[tL][p] > 0) {
              sumR += radii[tL][p];
              sumC += colors[tL][p];
              n++;
            }

            // Check Right
            int tR = (t + 1) % tRes;
            if (radii[tR][p] > 0) {
              sumR += radii[tR][p];
              sumC += colors[tR][p];
              n++;
            }

            // Check Up
            if (p > 0 && radii[t][p - 1] > 0) {
              sumR += radii[t][p - 1];
              sumC += colors[t][p - 1];
              n++;
            }

            // Check Down
            if (p < pRes - 1 && radii[t][p + 1] > 0) {
              sumR += radii[t][p + 1];
              sumC += colors[t][p + 1];
              n++;
            }

            if (n > 0) {
              newRadii[t][p] = sumR / n;
              newColors[t][p] = sumC / n.toDouble();
            } else {
              hasZeros = true;
            }
          }
        }
      }
      radii = newRadii;
      colors = newColors;
    }

    // 5. Generate Final Watertight Vertices
    int vCount = tRes * pRes;
    Float32List outVertices = Float32List(vCount * 3);
    Float32List outColors = Float32List(vCount * 3);
    Float32List outNormals = Float32List(vCount * 3);
    Float32List uvs = Float32List(vCount * 2);

    int vIdx = 0;
    for (int t = 0; t < tRes; t++) {
      double theta = (t / tRes) * 2 * math.pi;
      for (int p = 0; p < pRes; p++) {
        double phi = (p / (pRes - 1)) * math.pi;

        double r = radii[t][p];

        // Spherical to Cartesian normal
        double nx = math.sin(phi) * math.cos(theta);
        double ny = math.cos(phi);
        double nz = math.sin(phi) * math.sin(theta);

        Vector3 normal = Vector3(nx, ny, nz);
        Vector3 pos = center + (normal * r);

        outVertices[vIdx * 3] = pos.x;
        outVertices[vIdx * 3 + 1] = pos.y;
        outVertices[vIdx * 3 + 2] = pos.z;

        outNormals[vIdx * 3] = nx;
        outNormals[vIdx * 3 + 1] = ny;
        outNormals[vIdx * 3 + 2] = nz;

        outColors[vIdx * 3] = colors[t][p].x;
        outColors[vIdx * 3 + 1] = colors[t][p].y;
        outColors[vIdx * 3 + 2] = colors[t][p].z;

        uvs[vIdx * 2] = t / tRes;
        uvs[vIdx * 2 + 1] = p / (pRes - 1);

        vIdx++;
      }
    }

    // 6. Generate Indices
    List<int> indices = [];
    for (int t = 0; t < tRes; t++) {
      int tNext = (t + 1) % tRes;
      for (int p = 0; p < pRes - 1; p++) {
        int i00 = t * pRes + p;
        int i10 = tNext * pRes + p;
        int i01 = t * pRes + (p + 1);
        int i11 = tNext * pRes + (p + 1);

        indices.addAll([i00, i10, i01]);
        indices.addAll([i10, i11, i01]);
      }
    }

    return MeshData(
        vertices: outVertices,
        indices: Uint32List.fromList(indices),
        normals: outNormals,
        uvs: uvs,
        colors: outColors);
  }
}
