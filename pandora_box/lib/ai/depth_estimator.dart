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
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  /// Helper to flatten any multi-dimensional list TFLite throws at us
  List<double> _flatten(List<dynamic> list) {
    List<double> result = [];
    for (var element in list) {
      if (element is List) {
        result.addAll(_flatten(element as List<dynamic>));
      } else {
        result.add(element as double);
      }
    }
    return result;
  }

  /// Input: Raw RGB Float32List (0-255 values)
  Float32List estimate(Float32List rgbInput) {
    if (!_isLoaded || _interpreter == null) {
      throw StateError('[DepthEstimator] Model not loaded');
    }

    // ── 1. DYNAMIC SHAPE ALLOCATION ─────────────────────────────────
    // We ask the model EXACTLY what it wants, so we never mismatch
    final inShape = _interpreter!.getInputTensor(0).shape;
    final outShape = _interpreter!.getOutputTensor(0).shape;
    final outElements = _interpreter!.getOutputTensor(0).numElements();

    // ── 2. IMAGENET NORMALIZATION (CRITICAL FOR DEPTH ANYTHING) ─────
    // The model will output 0.0 if we don't do this exact math
    var processedInput = Float32List(rgbInput.length);
    for (int i = 0; i < rgbInput.length; i += 3) {
      processedInput[i] = ((rgbInput[i] / 255.0) - 0.485) / 0.229; // R
      processedInput[i + 1] = ((rgbInput[i + 1] / 255.0) - 0.456) / 0.224; // G
      processedInput[i + 2] = ((rgbInput[i + 2] / 255.0) - 0.406) / 0.225; // B
    }

    // ── 3. EXECUTE INFERENCE ────────────────────────────────────────
    var inputData = processedInput.reshape(inShape);
    var outputData = List.filled(outElements, 0.0).reshape(outShape);

    _interpreter!.run(inputData, outputData);

    // ── 4. SAFE FLATTENING ──────────────────────────────────────────
    final rawOutput = _flatten(outputData as List<dynamic>);

    // ── 5. MIN-MAX NORMALIZATION (0.0 to 1.0 for Point Cloud) ───────
    double min = double.infinity;
    double max = double.negativeInfinity;
    for (final v in rawOutput) {
      if (v < min) min = v;
      if (v > max) max = v;
    }

    final range = max - min;
    final normalized = Float32List(rawOutput.length);

    // Safety check in case the model STILL outputs pure zeros
    if (range > 0.0001) {
      for (int i = 0; i < rawOutput.length; i++) {
        normalized[i] = (rawOutput[i] - min) / range;
      }
    } else {
      // If we hit this, the TFLite model file itself is corrupted/empty
      for (int i = 0; i < rawOutput.length; i++) {
        normalized[i] = 0.5;
      }
    }

    return normalized;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
