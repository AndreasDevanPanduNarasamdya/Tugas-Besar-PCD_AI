import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
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

  static List<double> _flatten(List<dynamic> list) {
    List<double> result = [];
    for (var element in list) {
      if (element is List) {
        result.addAll(_flatten(element as List<dynamic>));
      } else if (element is double) {
        result.add(element);
      } else if (element is int) {
        result.add(element.toDouble());
      }
    }
    return result;
  }

  Future<void> start() async {
    _receivePort = ReceivePort();

    // 1. Load the models as raw bytes on the main thread
    final depthByteData =
        await rootBundle.load('assets/models/depth_anything_v2_small.tflite');
    final segByteData =
        await rootBundle.load('assets/models/mediapipe_segmentation.tflite');

    final depthBytes = depthByteData.buffer.asUint8List();
    final segBytes = segByteData.buffer.asUint8List();

    // 2. Pass the bytes into the Isolate
    _isolate = await Isolate.spawn(
      _isolateEntry,
      [_receivePort!.sendPort, depthBytes, segBytes],
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
// Note the parameter change to List<dynamic>
  static void _isolateEntry(List<dynamic> args) async {
    // 1. Unpack the arguments (No tokens, just bytes!)
    SendPort mainSendPort = args[0] as SendPort;
    Uint8List depthBytes = args[1] as Uint8List;
    Uint8List segBytes = args[2] as Uint8List;

    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    Interpreter? depthInterpreter;
    Interpreter? segInterpreter;

    // 2. Load models from the buffers directly
    try {
      depthInterpreter = Interpreter.fromBuffer(depthBytes);
      segInterpreter = Interpreter.fromBuffer(segBytes);
      print('[InferenceIsolate] Both models loaded in isolate');
    } catch (e) {
      print('[InferenceIsolate] Failed to load models: $e');
    }

    // ... The rest of your await for (final message in receivePort) loop stays here

    // ... The rest of your await for (final message in receivePort) loop stays exactly the same

    await for (final message in receivePort) {
      if (message is InferenceRequest) {
        try {
          if (message.type == InferenceType.depth) {
            // NATIVE DEPTH (518x518)
            final outputData =
                List.filled(1 * 518 * 518 * 1, 0.0).reshape([1, 518, 518, 1]);

            depthInterpreter!.run(
              message.input.reshape([1, 518, 518, 3]),
              outputData,
            );

            // ... (keep your normalize logic)

            final flatOutput = _flatten(outputData as List<dynamic>);
            final output = Float32List.fromList(flatOutput);

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
              normalized[i] = range > 1e-6 ? (output[i] - min) / range : 0.0;
            }
            message.replyPort.send(InferenceResult(depthMap: normalized));
          } else {
            // NATIVE SEGMENTATION (256x256)
            var output =
                List.filled(1 * 256 * 256 * 6, 0.0).reshape([1, 256, 256, 6]);

            segInterpreter!.run(
              message.input.reshape([1, 256, 256, 3]),
              output,
            );

            final flatOutput = _flatten(output as List<dynamic>);

            // Argmax → binary mask (256x256)
            final mask = Uint8List(256 * 256);
            for (int i = 0; i < 256 * 256; i++) {
              int maxClass = 0;
              double maxVal = flatOutput[i * 6];
              for (int c = 1; c < 6; c++) {
                final val = flatOutput[i * 6 + c];
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
