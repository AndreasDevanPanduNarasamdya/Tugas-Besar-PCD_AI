import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'scan_model.g.dart'; // <--- THIS WAS MISSING!

/// Hive-persisted 3D scan model.
/// After editing this file, regenerate the adapter:
///   dart run build_runner build --delete-conflicting-outputs
@HiveType(typeId: 0)
class ScanModel extends HiveObject {
  @HiveField(0)
  late String modelId;

  @HiveField(1)
  late String modelName;

  @HiveField(2)
  late DateTime timestamp;

  @HiveField(3)
  late Uint8List thumbnail; // Small JPEG preview shown in list

  @HiveField(4)
  late Uint8List baseMap; // Base color texture map

  @HiveField(5)
  late Uint8List normalMap; // Normal map for shading

  @HiveField(6)
  late Uint8List pointCloud; // Serialized point cloud data

  @HiveField(7)
  late String
      exportPath; // Path to exported .obj/.glb file (empty if not exported)

  @HiveField(8)
  late int frameCount; // How many camera frames were captured

  @HiveField(9)
  late bool isMeshGenerated;

  @HiveField(10)
  late int faceCount;

  @HiveField(11)
  late int vertexCount;

  @HiveField(12)
  late int edgeCount;

  @HiveField(13)
  late int triangleCount;

  @HiveField(14)
  late double fileSizeMb;

  // ── Derived helpers used by the UI ────────────────────────────────────

  String get formattedDate {
    return '${timestamp.day.toString().padLeft(2, '0')} '
        '${_monthName(timestamp.month)} ${timestamp.year}';
  }

  String get fileSizeLabel {
    if (fileSizeMb >= 1000) {
      return '${(fileSizeMb / 1024).toStringAsFixed(1)} GB';
    }
    return '${fileSizeMb.toStringAsFixed(0)} MB';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

class MeshModel {
  final int faceCount;
  final int vertexCount;
  final int edgeCount;
  final int triangleCount;
  final Float32List? uvs;
  final Float32List? normals;
  final List<int>? indices;

  MeshModel({
    this.faceCount = 0,
    this.vertexCount = 0,
    this.edgeCount = 0,
    this.triangleCount = 0,
    this.uvs,
    this.normals,
    this.indices,
  });
}
