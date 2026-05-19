import 'package:flutter/services.dart';

class EnvConfig {
  static late String depthModelPath;
  static late String segmentationModelPath;
  static late int depthInputSize;
  static late int segmentationInputSize;
  static late int segmentationClasses;
  static late double depthConfidenceThreshold;
  static late double segmentationConfidenceThreshold;
  static late int maxPointCloudPoints;
  static late int textureResolution;
  static late String scanQuality;

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/.env');
    final lines = raw.split('\n');
    final map = <String, String>{};

    for (final line in lines) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length < 2) continue;
      map[parts[0].trim()] = parts[1].trim();
    }

    depthModelPath = map['DEPTH_MODEL_PATH'] ??
        'assets/models/depth_anything_v2_small.tflite';
    segmentationModelPath = map['SEGMENTATION_MODEL_PATH'] ??
        'assets/models/mediapipe_segmentation.tflite';
    depthInputSize = int.tryParse(map['DEPTH_INPUT_SIZE'] ?? '518') ?? 518;
    segmentationInputSize =
        int.tryParse(map['SEGMENTATION_INPUT_SIZE'] ?? '256') ?? 256;
    segmentationClasses = int.tryParse(map['SEGMENTATION_CLASSES'] ?? '6') ?? 6;
    depthConfidenceThreshold =
        double.tryParse(map['DEPTH_CONFIDENCE_THRESHOLD'] ?? '0.5') ?? 0.5;
    segmentationConfidenceThreshold =
        double.tryParse(map['SEGMENTATION_CONFIDENCE_THRESHOLD'] ?? '0.7') ??
            0.7;
    maxPointCloudPoints =
        int.tryParse(map['MAX_POINT_CLOUD_POINTS'] ?? '50000') ?? 50000;
    textureResolution =
        int.tryParse(map['TEXTURE_RESOLUTION'] ?? '2048') ?? 2048;
    scanQuality = map['SCAN_QUALITY'] ?? 'balanced';

    print('[EnvConfig] Loaded successfully');
    print('[EnvConfig] Depth model: $depthModelPath');
    print('[EnvConfig] Scan quality: $scanQuality');
  }
}
