import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class InferenceRequest {
  final Float32List input;
  final SendPort replyPort;

  InferenceRequest({
    required this.input,
    required this.replyPort,
  });
}

class InferenceResult {
  final Float32List? depthMap;
  final String? error;

  InferenceResult({this.depthMap, this.error});
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
    if (_isRunning) return;
    _receivePort = ReceivePort();

    // 1. Load ONLY the depth model as raw bytes on the main thread
    final depthByteData =
        await rootBundle.load('assets/models/depth_anything_v2_small.tflite');
    final depthBytes = depthByteData.buffer.asUint8List();

    // 2. Spawn the isolate with just the single model buffer
    _isolate = await Isolate.spawn(
      _isolateEntry,
      [_receivePort!.sendPort, depthBytes],
    );

    _sendPort = await _receivePort!.first;
    _isRunning = true;
    print('[InferenceIsolate] Dedicated Depth Isolate Started');
  }

  Future<InferenceResult> runDepth(Float32List input) async {
    if (!_isRunning || _sendPort == null) {
      return InferenceResult(error: 'Isolate not running');
    }

    final replyPort = ReceivePort();
    _sendPort!.send(InferenceRequest(
      input: input,
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

  // ── Isolate Entry Point (Background Thread) ────────────────────────────────
  static void _isolateEntry(List<dynamic> args) async {
    SendPort mainSendPort = args[0] as SendPort;
    Uint8List depthBytes = args[1] as Uint8List;

    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    Interpreter? depthInterpreter;

    // Load model into background memory
    try {
      depthInterpreter = Interpreter.fromBuffer(depthBytes);
      print('[InferenceIsolate] Depth model loaded in isolate background');
    } catch (e) {
      print('[InferenceIsolate] Failed to load depth model: $e');
      mainSendPort
          .send(InferenceResult(error: 'Failed to initialize interpreter: $e'));
      return;
    }

    // Processing Loop
    await for (final message in receivePort) {
      if (message is InferenceRequest) {
        try {
          // Allocate tensor shapes for Depth Anything V2 (518x518)
          final outputData =
              List.filled(1 * 518 * 518 * 1, 0.0).reshape([1, 518, 518, 1]);

          // Run execution
          depthInterpreter.run(
            message.input.reshape([1, 518, 518, 3]),
            outputData,
          );

          // Flatten nested multidimensional List back to flat array
          final flatOutput = _flatten(outputData as List<dynamic>);
          final output = Float32List.fromList(flatOutput);

          // Min-Max Normalization to map values cleanly between 0.0 and 1.0
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

          // Return result to Main Thread
          message.replyPort.send(InferenceResult(depthMap: normalized));
        } catch (e) {
          message.replyPort.send(InferenceResult(error: e.toString()));
        }
      }
    }
  }
}
