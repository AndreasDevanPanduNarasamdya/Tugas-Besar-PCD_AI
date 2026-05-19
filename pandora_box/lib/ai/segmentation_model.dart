import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class SegmentationModel {
  static const String _modelPath =
      'assets/models/mediapipe_segmentation.tflite';
  static const int inputSize = 256;
  static const int numClasses = 6;

  Interpreter? _interpreter;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isLoaded = true;
      print('[SegmentationModel] Model loaded successfully');
    } catch (e) {
      _isLoaded = false;
      print('[SegmentationModel] Failed to load model: $e');
      rethrow;
    }
  }

  /// Input: RGB Float32List of size 256x256x3
  /// Output: Uint8List mask where 0=background, 255=object
  Uint8List segment(Float32List rgbInput) {
    if (!_isLoaded || _interpreter == null) {
      throw StateError('[SegmentationModel] Model not loaded');
    }

    // Output buffer [1, 256, 256, 6]
    var outputBuffer = Float32List(1 * inputSize * inputSize * numClasses);

    _interpreter!.run(
      rgbInput.reshape([1, inputSize, inputSize, 3]),
      outputBuffer.reshape([1, inputSize, inputSize, numClasses]),
    );

    // Convert 6-class logits to binary mask via argmax
    // class 0 = background, anything else = object
    final mask = Uint8List(inputSize * inputSize);
    for (int i = 0; i < inputSize * inputSize; i++) {
      int maxClass = 0;
      double maxVal = outputBuffer[i * numClasses];
      for (int c = 1; c < numClasses; c++) {
        final val = outputBuffer[i * numClasses + c];
        if (val > maxVal) {
          maxVal = val;
          maxClass = c;
        }
      }
      mask[i] = maxClass > 0 ? 255 : 0;
    }

    return mask;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    print('[SegmentationModel] Disposed');
  }
}
