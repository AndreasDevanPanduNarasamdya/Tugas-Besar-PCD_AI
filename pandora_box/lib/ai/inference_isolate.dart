import 'dart:isolate';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

enum InferenceType { depth, segmentation }

class InferenceRequest {
  final Float32List input;
  final InferenceType type;
  final SendPort replyPort;

  InferenceRequest({
    required this.input,
    required this.type,
    required this.replyPort,
  });
}

class InferenceResult {
  final Float32List? depthMap;
  final Uint8List? segmentationMask;
  final String? error;

  InferenceResult({this.depthMap, this.segmentationMask, this.error});
}

class InferenceIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntry,
      _receivePort!.sendPort,
    );

    _sendPort = await _receivePort!.first;
    _isRunning = true;
    print('[InferenceIsolate] Started');
  }

  Future<InferenceResult> runDepth(Float32List input) async {
    if (!_isRunning || _sendPort == null) {
      return InferenceResult(error: 'Isolate not running');
    }

    final replyPort = ReceivePort();
    _sendPort!.send(InferenceRequest(
      input: input,
      type: InferenceType.depth,
      replyPort: replyPort.sendPort,
    ));

    final result = await replyPort.first as InferenceResult;
    replyPort.close();
    return result;
  }

  Future<InferenceResult> runSegmentation(Float32List input) async {
    if (!_isRunning || _sendPort == null) {
      return InferenceResult(error: 'Isolate not running');
    }

    final replyPort = ReceivePort();
    _sendPort!.send(InferenceRequest(
      input: input,
      type: InferenceType.segmentation,
      replyPort: replyPort.sendPort,
    ));

    final result = await replyPort.first as InferenceResult;
    replyPort.close();
    return result;
  }

  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
    _isRunning = false;
    print('[InferenceIsolate] Stopped');
  }

  // Isolate entry point — runs in separate thread
  static void _isolateEntry(SendPort mainSendPort) async {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    Interpreter? depthInterpreter;
    Interpreter? segInterpreter;

    // Load both models once inside isolate
    try {
      depthInterpreter = await Interpreter.fromAsset(
        'assets/models/depth_anything_v2_small.tflite',
      );
      segInterpreter = await Interpreter.fromAsset(
        'assets/models/mediapipe_segmentation.tflite',
      );
      print('[InferenceIsolate] Both models loaded in isolate');
    } catch (e) {
      print('[InferenceIsolate] Failed to load models: $e');
    }

    await for (final message in receivePort) {
      if (message is InferenceRequest) {
        try {
          if (message.type == InferenceType.depth) {
            // Run depth estimation
            var output = Float32List(1 * 518 * 518 * 1);
            depthInterpreter!.run(
              message.input.reshape([1, 518, 518, 3]),
              output.reshape([1, 518, 518, 1]),
            );

            // Normalize
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

            message.replyPort.send(InferenceResult(depthMap: normalized));
          } else {
            // Run segmentation
            var output = Float32List(1 * 256 * 256 * 6);
            segInterpreter!.run(
              message.input.reshape([1, 256, 256, 3]),
              output.reshape([1, 256, 256, 6]),
            );

            // Argmax → binary mask
            final mask = Uint8List(256 * 256);
            for (int i = 0; i < 256 * 256; i++) {
              int maxClass = 0;
              double maxVal = output[i * 6];
              for (int c = 1; c < 6; c++) {
                final val = output[i * 6 + c];
                if (val > maxVal) {
                  maxVal = val;
                  maxClass = c;
                }
              }
              mask[i] = maxClass > 0 ? 255 : 0;
            }

            message.replyPort.send(InferenceResult(segmentationMask: mask));
          }
        } catch (e) {
          message.replyPort.send(InferenceResult(error: e.toString()));
        }
      }
    }
  }
}
