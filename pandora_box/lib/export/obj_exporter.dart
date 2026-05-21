import 'dart:typed_data';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../reconstruction/mesh_generator.dart';

class ObjExporter {
  Future<String> export({
    required MeshData mesh,
    required Uint8List baseMapBytes,
    required Uint8List normalMapBytes,
    required String scanName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports/$scanName');
    await exportDir.create(recursive: true);

    final objContent = _generateObj(mesh, scanName);
    final objFile = File('${exportDir.path}/$scanName.obj');
    await objFile.writeAsString(objContent);

    final mtlContent = _generateMtl(scanName);
    final mtlFile = File('${exportDir.path}/$scanName.mtl');
    await mtlFile.writeAsString(mtlContent);

    final baseMapFile = File('${exportDir.path}/${scanName}_base_color.png');
    await baseMapFile.writeAsBytes(baseMapBytes);

    final normalMapFile = File('${exportDir.path}/${scanName}_normal_map.png');
    await normalMapFile.writeAsBytes(normalMapBytes);

    final archive = Archive();
    archive.addFile(ArchiveFile(
        '$scanName.obj', objFile.lengthSync(), await objFile.readAsBytes()));
    archive.addFile(ArchiveFile(
        '$scanName.mtl', mtlFile.lengthSync(), await mtlFile.readAsBytes()));
    archive.addFile(ArchiveFile('${scanName}_base_color.png',
        baseMapFile.lengthSync(), await baseMapFile.readAsBytes()));
    archive.addFile(ArchiveFile('${scanName}_normal_map.png',
        normalMapFile.lengthSync(), await normalMapFile.readAsBytes()));

    final zipBytes = ZipEncoder().encode(archive)!;
    final zipFile = File('${dir.path}/exports/$scanName.zip');
    await zipFile.writeAsBytes(zipBytes);

    print('[ObjExporter] Exported to: ${zipFile.path}');
    return zipFile.path;
  }

  Future<void> share(String zipPath) async {
    await Share.shareXFiles(
      [XFile(zipPath)],
      subject: 'Pandora Box 3D Scan Export',
    );
  }

  String _generateObj(MeshData mesh, String name) {
    final sb = StringBuffer();
    sb.writeln('# Pandora Box 3D Scan Export');
    sb.writeln('mtllib $name.mtl');
    sb.writeln('usemtl material0');
    sb.writeln();

    for (int i = 0; i < mesh.vertexCount; i++) {
      final x = mesh.vertices[i * 3];
      final y = mesh.vertices[i * 3 + 1];
      final z = mesh.vertices[i * 3 + 2];
      sb.writeln(
          'v ${x.toStringAsFixed(6)} ${y.toStringAsFixed(6)} ${z.toStringAsFixed(6)}');
    }
    sb.writeln();

    for (int i = 0; i < mesh.vertexCount; i++) {
      final nx = mesh.normals[i * 3];
      final ny = mesh.normals[i * 3 + 1];
      final nz = mesh.normals[i * 3 + 2];
      sb.writeln(
          'vn ${nx.toStringAsFixed(6)} ${ny.toStringAsFixed(6)} ${nz.toStringAsFixed(6)}');
    }
    sb.writeln();

    for (int i = 0; i < mesh.vertexCount; i++) {
      final u = mesh.uvs[i * 2];
      final v = mesh.uvs[i * 2 + 1];
      sb.writeln('vt ${u.toStringAsFixed(6)} ${v.toStringAsFixed(6)}');
    }
    sb.writeln();

    for (int i = 0; i < mesh.indices.length; i += 3) {
      final a = mesh.indices[i] + 1;
      final b = mesh.indices[i + 1] + 1;
      final c = mesh.indices[i + 2] + 1;
      sb.writeln('f $a/$a/$a $b/$b/$b $c/$c/$c');
    }

    return sb.toString();
  }

  String _generateMtl(String name) {
    return '''
# Pandora Box Material
newmtl material0
Ka 1.000 1.000 1.000
Kd 1.000 1.000 1.000
Ks 0.000 0.000 0.000
d 1.0
illum 2
map_Kd ${name}_base_color.png
map_bump ${name}_normal_map.png
''';
  }
}
