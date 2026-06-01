import 'package:flutter/services.dart';

class EnvConfig {
  static late String depthModelPath;
  static late int depthInputSize; // <-- Kept this!

  static late double depthConfidenceThreshold;
  static late double
      segmentationConfidenceThreshold; // Re-using as Depth Tolerance!

  static late int textureResolution;
  static late String scanQuality;
  static late int captureCount;
  static late double focalLength;
  static late double edgeThreshold;
  static late double cameraZOffset;
  static late int targetPoints;
  static late double voxelSize;
  static late int jpegQuality;
  static late int thumbnailQuality;
  static late double sharpenStrength;
  static late double sharpenStrengthNormal;
  static late int meshGridSize;
  static late String cameraResolution;
  static late int pointCloudMaxPoints;

  // ── NEW: Spherical Mesh Resolution ──
  static late int meshThetaRes;
  static late int meshPhiRes;

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/.env');
    final lines = raw.split('\n');
    final map = <String, String>{};

    // Parse file FIRST — then read from map
    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length < 2) continue;
      map[parts[0].trim()] = parts[1].trim();
    }

    depthModelPath = map['DEPTH_MODEL_PATH'] ??
        'assets/models/depth_anything_v2_small.tflite';

    // <-- UNCOMMENTED THIS! The AI still needs to know it's 518x518
    depthInputSize = int.tryParse(map['DEPTH_INPUT_SIZE'] ?? '518') ?? 518;

    depthConfidenceThreshold =
        double.tryParse(map['DEPTH_CONFIDENCE_THRESHOLD'] ?? '0.5') ?? 0.5;
    segmentationConfidenceThreshold =
        double.tryParse(map['SEGMENTATION_CONFIDENCE_THRESHOLD'] ?? '0.15') ??
            0.15; // Your slicing thickness
    textureResolution =
        int.tryParse(map['TEXTURE_RESOLUTION'] ?? '2048') ?? 2048;
    scanQuality = map['SCAN_QUALITY'] ?? 'balanced';
    captureCount = int.tryParse(map['CAPTURE_COUNT'] ?? '4') ?? 4;
    focalLength = double.tryParse(map['FOCAL_LENGTH'] ?? '500.0') ?? 500.0;
    edgeThreshold = double.tryParse(map['EDGE_THRESHOLD'] ?? '0.05') ?? 0.05;
    cameraZOffset = double.tryParse(map['CAMERA_Z_OFFSET'] ?? '0.3') ?? 0.3;
    targetPoints = int.tryParse(map['TARGET_POINTS'] ?? '8000') ?? 8000;
    voxelSize = double.tryParse(map['VOXEL_SIZE'] ?? '0.02') ?? 0.02;
    jpegQuality = int.tryParse(map['JPEG_QUALITY'] ?? '75') ?? 75;
    thumbnailQuality = int.tryParse(map['THUMBNAIL_QUALITY'] ?? '60') ?? 60;
    sharpenStrength = double.tryParse(map['SHARPEN_STRENGTH'] ?? '0.5') ?? 0.5;
    sharpenStrengthNormal =
        double.tryParse(map['SHARPEN_STRENGTH_NORMAL'] ?? '0.3') ?? 0.3;
    meshGridSize = int.tryParse(map['MESH_GRID_SIZE'] ?? '10') ?? 10;
    cameraResolution = map['CAMERA_RESOLUTION'] ?? 'high';
    pointCloudMaxPoints =
        int.tryParse(map['POINT_CLOUD_MAX_POINTS'] ?? '3000') ?? 3000;

    // ── NEW: Parse Spherical Mesh Resolution ──
    meshThetaRes = int.tryParse(map['MESH_THETA_RES'] ?? '60') ?? 60;
    meshPhiRes = int.tryParse(map['MESH_PHI_RES'] ?? '60') ?? 60;

    print('[EnvConfig] Loaded successfully');
    print('[EnvConfig] Depth model: $depthModelPath');
    print('[EnvConfig] Scan quality: $scanQuality');
  }
}
