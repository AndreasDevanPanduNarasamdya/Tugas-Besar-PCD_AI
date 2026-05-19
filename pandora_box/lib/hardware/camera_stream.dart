import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

typedef FrameCallback = void Function(
  Uint8List rgbBytes,
  int width,
  int height,
);

class CameraStream {
  CameraController? _controller;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;

  bool get isStreaming => _isStreaming;
  CameraController? get controller => _controller;

  Future<void> initialize({
    required FrameCallback onFrame,
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    // Use back camera
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      backCamera,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    print('[CameraStream] Camera initialized');

    await _startImageStream(onFrame);
  }

  Future<void> _startImageStream(FrameCallback onFrame) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    await _controller!.startImageStream((CameraImage image) {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final bytes = _convertYuv420ToRgb(image);
        if (bytes != null) {
          onFrame(bytes, image.width, image.height);
        }
      } catch (e) {
        print('[CameraStream] Frame conversion error: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });

    _isStreaming = true;
    print('[CameraStream] Image stream started');
  }

  Uint8List? _convertYuv420ToRgb(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      final rgb = Uint8List(width * height * 3);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * width + x;
          final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

          if (yIndex >= yPlane.length) continue;
          if (uvIndex >= uPlane.length || uvIndex >= vPlane.length) continue;

          final yVal = yPlane[yIndex].toDouble();
          final uVal = uPlane[uvIndex].toDouble() - 128;
          final vVal = vPlane[uvIndex].toDouble() - 128;

          final r = (yVal + 1.402 * vVal).round().clamp(0, 255);
          final g =
              (yVal - 0.344136 * uVal - 0.714136 * vVal).round().clamp(0, 255);
          final b = (yVal + 1.772 * uVal).round().clamp(0, 255);

          final idx = yIndex * 3;
          rgb[idx] = r;
          rgb[idx + 1] = g;
          rgb[idx + 2] = b;
        }
      }

      return rgb;
    } catch (e) {
      print('[CameraStream] YUV conversion error: $e');
      return null;
    }
  }

  Future<void> stopStream() async {
    if (_controller != null && _isStreaming) {
      await _controller!.stopImageStream();
      _isStreaming = false;
      print('[CameraStream] Stream stopped');
    }
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    print('[CameraStream] Disposed');
  }
}
