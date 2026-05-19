import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class DepthEstimator {
  static const String _modelPath =
      'assets/models/depth_anything_v2_small.tflite';
  static const int inputSize = 518;

  Interpreter? _interpreter;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isLoaded = true;
      print('[DepthEstimator] Model loaded successfully');
    } catch (e) {
      _isLoaded = false;
      print('[DepthEstimator] Failed to load model: $e');
      rethrow;
    }
  }

  /// Input: RGB Float32List of size 518x518x3
  /// Output: Float32List of size 518x518 (depth per pixel, normalized)
  Float32List estimate(Float32List rgbInput) {
    if (!_isLoaded || _interpreter == null) {
      throw StateError('[DepthEstimator] Model not loaded');
    }

    // Reshape input to [1, 518, 518, 3]
    var input = rgbInput.buffer.asFloat32List();

    // Output buffer [1, 518, 518, 1]
    var outputBuffer = Float32List(1 * inputSize * inputSize * 1);
    var output = outputBuffer.buffer.asFloat32List();

    _interpreter!.run(
      input.reshape([1, inputSize, inputSize, 3]),
      output.reshape([1, inputSize, inputSize, 1]),
    );

    // Normalize output to [0, 1]
    double min = double.infinity;
    double max = double.negativeInfinity;
    for (final v in output) {
      if (v < min) min = v;
      if (v > max) max = v;
    }

    final range = max - min;
    final normalized = Float32List(output.length);
    for (int i = 0; i < output.length; i++) {
      normalized[i] = range > 0 ? (output[i] - min) / range : 0.0;
    }

    return normalized;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    print('[DepthEstimator] Disposed');
  }
}
