import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'mesh_generator.dart';

class TextureMapper {
  static const int textureSize = 2048;

  img.Image generateBaseColorMap(
    MeshData mesh,
    List<Uint8List> frames,
    List<int> frameWidths,
    List<int> frameHeights,
  ) {
    final texture = img.Image(width: textureSize, height: textureSize);
    img.fill(texture, color: img.ColorRgb8(128, 128, 128));

    if (frames.isEmpty || mesh.indices.isEmpty) return texture;

    for (int t = 0; t < mesh.indices.length; t += 3) {
      final a = mesh.indices[t];
      final b = mesh.indices[t + 1];
      final c = mesh.indices[t + 2];

      if (a >= mesh.vertexCount ||
          b >= mesh.vertexCount ||
          c >= mesh.vertexCount) continue;

      final uvA = _getUV(mesh.uvs, a);
      final uvB = _getUV(mesh.uvs, b);
      final uvC = _getUV(mesh.uvs, c);

      // Pick best frame — use middle frame for now
      final frameIdx = frames.length ~/ 2;
      final frame = frames[frameIdx];
      final fw = frameWidths[frameIdx];
      final fh = frameHeights[frameIdx];

      _rasterizeTriangle(texture, uvA, uvB, uvC, frame, fw, fh);
    }

    return _sharpen(texture);
  }

  img.Image generateNormalMap(MeshData mesh) {
    final texture = img.Image(width: textureSize, height: textureSize);
    img.fill(texture, color: img.ColorRgb8(128, 128, 255));

    if (mesh.indices.isEmpty) return texture;

    for (int t = 0; t < mesh.indices.length; t += 3) {
      final a = mesh.indices[t];
      final b = mesh.indices[t + 1];
      final c = mesh.indices[t + 2];

      if (a >= mesh.vertexCount ||
          b >= mesh.vertexCount ||
          c >= mesh.vertexCount) continue;

      final uvA = _getUV(mesh.uvs, a);
      final uvB = _getUV(mesh.uvs, b);
      final uvC = _getUV(mesh.uvs, c);

      final nA = _getNormal(mesh.normals, a);
      final nB = _getNormal(mesh.normals, b);
      final nC = _getNormal(mesh.normals, c);

      final avgNX = (nA[0] + nB[0] + nC[0]) / 3;
      final avgNY = (nA[1] + nB[1] + nC[1]) / 3;
      final avgNZ = (nA[2] + nB[2] + nC[2]) / 3;

      final r = ((avgNX + 1) / 2 * 255).round().clamp(0, 255);
      final g = ((avgNY + 1) / 2 * 255).round().clamp(0, 255);
      final b2 = ((avgNZ + 1) / 2 * 255).round().clamp(0, 255);

      _rasterizeTriangleColor(texture, uvA, uvB, uvC, r, g, b2);
    }

    return texture;
  }

  List<double> _getUV(Float32List uvs, int idx) {
    if (idx * 2 + 1 >= uvs.length) return [0.0, 0.0];
    return [uvs[idx * 2], uvs[idx * 2 + 1]];
  }

  List<double> _getNormal(Float32List normals, int idx) {
    if (idx * 3 + 2 >= normals.length) return [0.0, 0.0, 1.0];
    return [normals[idx * 3], normals[idx * 3 + 1], normals[idx * 3 + 2]];
  }

  void _rasterizeTriangle(
    img.Image texture,
    List<double> uvA,
    List<double> uvB,
    List<double> uvC,
    Uint8List frame,
    int fw,
    int fh,
  ) {
    final ax = (uvA[0] * textureSize).round().clamp(0, textureSize - 1);
    final ay = ((1 - uvA[1]) * textureSize).round().clamp(0, textureSize - 1);
    final bx = (uvB[0] * textureSize).round().clamp(0, textureSize - 1);
    final by = ((1 - uvB[1]) * textureSize).round().clamp(0, textureSize - 1);
    final cx = (uvC[0] * textureSize).round().clamp(0, textureSize - 1);
    final cy = ((1 - uvC[1]) * textureSize).round().clamp(0, textureSize - 1);

    final minX = [ax, bx, cx].reduce(min);
    final maxX = [ax, bx, cx].reduce(max);
    final minY = [ay, by, cy].reduce(min);
    final maxY = [ay, by, cy].reduce(max);

    for (int py = minY; py <= maxY; py++) {
      for (int px = minX; px <= maxX; px++) {
        final w = _barycentric(ax, ay, bx, by, cx, cy, px, py);
        if (w[0] < 0 || w[1] < 0 || w[2] < 0) continue;

        final u =
            (w[0] * uvA[0] + w[1] * uvB[0] + w[2] * uvC[0]).clamp(0.0, 1.0);
        final v =
            (w[0] * uvA[1] + w[1] * uvB[1] + w[2] * uvC[1]).clamp(0.0, 1.0);

        final fx = (u * fw).round().clamp(0, fw - 1);
        final fy = (v * fh).round().clamp(0, fh - 1);

        final frameIdx = (fy * fw + fx) * 3;
        if (frameIdx + 2 >= frame.length) continue;

        texture.setPixelRgb(
            px, py, frame[frameIdx], frame[frameIdx + 1], frame[frameIdx + 2]);
      }
    }
  }

  void _rasterizeTriangleColor(
    img.Image texture,
    List<double> uvA,
    List<double> uvB,
    List<double> uvC,
    int r,
    int g,
    int b,
  ) {
    final ax = (uvA[0] * textureSize).round().clamp(0, textureSize - 1);
    final ay = ((1 - uvA[1]) * textureSize).round().clamp(0, textureSize - 1);
    final bx = (uvB[0] * textureSize).round().clamp(0, textureSize - 1);
    final by = ((1 - uvB[1]) * textureSize).round().clamp(0, textureSize - 1);
    final cx = (uvC[0] * textureSize).round().clamp(0, textureSize - 1);
    final cy = ((1 - uvC[1]) * textureSize).round().clamp(0, textureSize - 1);

    final minX = [ax, bx, cx].reduce(min);
    final maxX = [ax, bx, cx].reduce(max);
    final minY = [ay, by, cy].reduce(min);
    final maxY = [ay, by, cy].reduce(max);

    for (int py = minY; py <= maxY; py++) {
      for (int px = minX; px <= maxX; px++) {
        final w = _barycentric(ax, ay, bx, by, cx, cy, px, py);
        if (w[0] < 0 || w[1] < 0 || w[2] < 0) continue;
        texture.setPixelRgb(px, py, r, g, b);
      }
    }
  }

  List<double> _barycentric(
    int ax,
    int ay,
    int bx,
    int by,
    int cx,
    int cy,
    int px,
    int py,
  ) {
    final denom = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
    if (denom == 0) return [-1, -1, -1];
    final wa = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / denom;
    final wb = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / denom;
    final wc = 1.0 - wa - wb;
    return [wa, wb, wc];
  }

  img.Image _sharpen(img.Image src) {
    final blurred = img.gaussianBlur(src, radius: 1);
    final result = img.Image(width: src.width, height: src.height);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final orig = src.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r = (orig.r + 0.5 * (orig.r - blur.r)).round().clamp(0, 255);
        final g = (orig.g + 0.5 * (orig.g - blur.g)).round().clamp(0, 255);
        final b = (orig.b + 0.5 * (orig.b - blur.b)).round().clamp(0, 255);

        result.setPixelRgb(x, y, r, g, b);
      }
    }
    return result;
  }
}
