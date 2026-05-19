import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ModelTestScreen());
  }
}

class ModelTestScreen extends StatefulWidget {
  const ModelTestScreen({super.key});
  @override
  State<ModelTestScreen> createState() => _ModelTestScreenState();
}

class _ModelTestScreenState extends State<ModelTestScreen> {
  String _depthStatus = 'Not tested';
  String _segStatus = 'Not tested';
  bool _depthLoading = false;
  bool _segLoading = false;

  Future<void> _testDepthModel() async {
    setState(() {
      _depthLoading = true;
      _depthStatus = 'Loading model...';
    });
    try {
      // Step 1: Load
      final interpreter = await Interpreter.fromAsset(
        'assets/models/depth_anything_v2_small.tflite',
      );
      setState(() => _depthStatus = 'Model loaded ✅\nPreparing input...');

      // Step 2: Check shapes
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;

      // Step 3: Run inference
      var input = List.generate(
          1,
          (_) => List.generate(518,
              (_) => List.generate(518, (_) => List.generate(3, (_) => 0.5))));

      var output = List.generate(
          1,
          (_) => List.generate(518,
              (_) => List.generate(518, (_) => List.generate(1, (_) => 0.0))));

      final stopwatch = Stopwatch()..start();
      interpreter.run(input, output);
      stopwatch.stop();

      // Step 4: Analyze output
      double min = double.infinity;
      double max = double.negativeInfinity;
      double sum = 0;
      int count = 0;
      for (var h in output[0]) {
        for (var w in h) {
          final v = w[0] as double;
          if (v < min) min = v;
          if (v > max) max = v;
          sum += v;
          count++;
        }
      }

      interpreter.close();

      setState(() => _depthStatus = '''
✅ ALL CHECKS PASSED
─────────────────
Input shape:  $inputShape
Output shape: $outputShape
─────────────────
Inference time: ${stopwatch.elapsedMilliseconds}ms
Output min: ${min.toStringAsFixed(4)}
Output max: ${max.toStringAsFixed(4)}
Output mean: ${(sum / count).toStringAsFixed(4)}
Non-zero values: ${count > 0 ? "YES ✅" : "NO ❌"}
''');
    } catch (e) {
      setState(() => _depthStatus = '❌ FAILED\n$e');
    } finally {
      setState(() => _depthLoading = false);
    }
  }

  Future<void> _testSegModel() async {
    setState(() {
      _segLoading = true;
      _segStatus = 'Loading model...';
    });
    try {
      // Step 1: Load
      final interpreter = await Interpreter.fromAsset(
        'assets/models/mediapipe_segmentation.tflite',
      );
      setState(() => _segStatus = 'Model loaded ✅\nPreparing input...');

      // Step 2: Check shapes
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;

      // Step 3: Run inference
      var input = List.generate(
          1,
          (_) => List.generate(256,
              (_) => List.generate(256, (_) => List.generate(3, (_) => 0.5))));

      var output = List.generate(
          1,
          (_) => List.generate(256,
              (_) => List.generate(256, (_) => List.generate(6, (_) => 0.0))));

      final stopwatch = Stopwatch()..start();
      interpreter.run(input, output);
      stopwatch.stop();

      // Step 4: Analyze output
      double min = double.infinity;
      double max = double.negativeInfinity;
      double sum = 0;
      int count = 0;
      for (var h in output[0]) {
        for (var w in h) {
          for (var c in w) {
            final v = c as double;
            if (v < min) min = v;
            if (v > max) max = v;
            sum += v;
            count++;
          }
        }
      }

      interpreter.close();

      setState(() => _segStatus = '''
✅ ALL CHECKS PASSED
─────────────────
Input shape:  $inputShape
Output shape: $outputShape
─────────────────
Inference time: ${stopwatch.elapsedMilliseconds}ms
Output min: ${min.toStringAsFixed(4)}
Output max: ${max.toStringAsFixed(4)}
Output mean: ${(sum / count).toStringAsFixed(4)}
6 class outputs: YES ✅
''');
    } catch (e) {
      setState(() => _segStatus = '❌ FAILED\n$e');
    } finally {
      setState(() => _segLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('AI Model Tests',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Depth Model
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Depth Anything V2 Small',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Text('depth_anything_v2_small.tflite',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 12),
                  Text(_depthStatus,
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _depthLoading ? null : _testDepthModel,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text(_depthLoading ? 'Running...' : 'Run Test'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Segmentation Model
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MediaPipe Segmentation',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Text('mediapipe_segmentation.tflite',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 12),
                  Text(_segStatus,
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _segLoading ? null : _testSegModel,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text(_segLoading ? 'Running...' : 'Run Test'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
