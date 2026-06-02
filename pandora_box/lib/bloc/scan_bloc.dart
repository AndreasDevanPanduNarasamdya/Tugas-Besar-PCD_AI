import 'dart:async';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math.dart';
import '../reconstruction/mesh_generator.dart';
import '../reconstruction/texture_mapper.dart';
import '../ai/inference_isolate.dart';
import '../processing/frame_preprocessor.dart';
import '../processing/object_segmenter.dart';
import '../processing/sharpener.dart';
import '../processing/space_carver.dart';
import '../reconstruction/mesh_generator.dart';
import '../reconstruction/texture_mapper.dart';
import '../storage/scan_repository.dart';
import '../export/obj_exporter.dart';
import '../config/env_config.dart';

part 'scan_event.dart';
part 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ScanRepository _repository;
  final ObjExporter _exporter;

  final InferenceIsolate _inferenceIsolate = InferenceIsolate();
  final FramePreprocessor _framePreprocessor = FramePreprocessor();

  CameraController? cameraController;

  // Raw RGB frames + dimensions
  final List<Uint8List> _capturedFrames = [];
  final List<int> _frameWidths = [];
  final List<int> _frameHeights = [];

  // NEW: Space Carver Accumulators
  final List<List<bool>> _allMasks = [];
  final List<Float32List> _allDepthMaps = [];
  final List<Matrix4> _allPoses = [];

  ScanBloc({
    required ScanRepository repository,
    required ObjExporter exporter,
  })  : _repository = repository,
        _exporter = exporter,
        super(const ScanState()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanPhotoCaptured>(_onPhotoCaptured);
    on<ScanMeshGenerationRequested>(_onMeshGenerationRequested);
    on<ScanRescanRequested>(_onRescanRequested);
    on<ScanSaveRequested>(_onSaveRequested);
    on<ScanExportRequested>(_onExportRequested);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _step(
    Emitter<ScanState> emit,
    ProcessingStep step,
    double progress,
    DateTime start, {
    String? extraNote,
  }) {
    final ms = DateTime.now().difference(start).inMilliseconds;
    final note = extraNote != null ? ' — $extraNote' : '';
    print(
        '[PIPELINE +${ms}ms] ${step.label}$note  (${(progress * 100).toInt()}%)');
    emit(state.copyWith(processingStep: step, processingProgress: progress));
  }

  // ── 1. ScanStarted ─────────────────────────────────────────────────────────

  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<ScanState> emit,
  ) async {
    print('[ScanBloc] ── ScanStarted ──────────────────────────');

    _capturedFrames.clear();
    _frameWidths.clear();
    _frameHeights.clear();

    // Wipe the carver slates clean
    _allMasks.clear();
    _allDepthMaps.clear();
    _allPoses.clear();

    emit(state.copyWith(
      status: ScanStatus.scanning,
      capturedCount: 0,
      isCapturingFrame: false,
      pointCount: 0,
      errorMessage: null,
      processingStep: ProcessingStep.idle,
    ));

    try {
      await _inferenceIsolate.start();

      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras found.');

      cameraController = CameraController(
        cameras.first,
        _resolutionPreset(EnvConfig.cameraResolution),
        enableAudio: false,
      );

      await cameraController!.initialize();
      emit(state.copyWith(isCameraReady: true));
    } catch (e, st) {
      print('[ScanBloc] Init error: $e\n$st');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Failed to start camera: $e',
      ));
    }
  }

  // ── 2. 4-Shot Orthogonal Capture ───────────────────────────────────────────

// ── 2. 4-Shot Orthogonal Capture ───────────────────────────────────────────

  Future<void> _onPhotoCaptured(
    ScanPhotoCaptured event,
    Emitter<ScanState> emit,
  ) async {
    if (state.capturedCount >= EnvConfig.captureCount ||
        state.isCapturingFrame ||
        cameraController == null) return;

    emit(state.copyWith(isCapturingFrame: true));

    try {
      // 1. Take picture
      final xFile = await cameraController!.takePicture();
      final rawBytes = await xFile.readAsBytes();
      final image = img.decodeImage(rawBytes);
      if (image == null) throw Exception('Failed to decode image');

      final w = image.width;
      final h = image.height;
      final rgb = image.getBytes(order: img.ChannelOrder.rgb);

      _capturedFrames.add(rgb);
      _frameWidths.add(w);
      _frameHeights.add(h);

      // 2. Run AI on this frame
      final depthInput = _framePreprocessor.prepareForDepth(rgb, w, h);
      final depthResult = await _inferenceIsolate.runDepth(depthInput);

      if (depthResult.error != null) throw Exception(depthResult.error);

      // ── THE FIX: DYNAMIC DEPTH CALIBRATION ────────────────────────────────
      // Check the exact center of the depth map to see how far away the bottle is
      final depthMap = depthResult.depthMap!;
      double centerSum = 0;
      int centerCount = 0;
      final int cx = EnvConfig.depthInputSize ~/ 2;
      final int cy = EnvConfig.depthInputSize ~/ 2;

      for (int y = cy - 15; y <= cy + 15; y++) {
        for (int x = cx - 15; x <= cx + 15; x++) {
          int idx = y * EnvConfig.depthInputSize + x;
          if (idx >= 0 && idx < depthMap.length) {
            centerSum += depthMap[idx];
            centerCount++;
          }
        }
      }

      // Convert raw AI depth (0.0-1.0) into physical Metric Distance (Meters)
      final rawDepth = centerCount > 0 ? (centerSum / centerCount) : 0.6;
      final metricDepth = 0.3 + (1.0 - rawDepth) * 3.0;

      // 3. Build orthogonal pose matrix
      // 3. Build orthogonal pose matrix
      final angleRad =
          (state.capturedCount * (360.0 / EnvConfig.captureCount)) *
              (math.pi / 180.0);

      // We pull the camera BACKWARDS (-metricDepth) along the local Z axis.
      // This guarantees the bottle is perfectly locked at (0,0,0) in world space!
      final pose = Matrix4.rotationY(angleRad)
        ..translate(0.0, 0.0, -metricDepth);

      // 4. Native Object Segmentation Mask
      // 4. Strict Object Segmentation Mask
      final validMask = ObjectSegmenter.generateMask(
        depthMap: depthMap,
        width: EnvConfig.depthInputSize,
        height: EnvConfig.depthInputSize,
        depthTolerance: 0.08, // Pass our new strict 8% tolerance directly!
      );

      // 5. Store them in memory for the final carve!
      _allMasks.add(validMask);
      _allDepthMaps.add(depthMap);
      _allPoses.add(pose);

      final newCount = state.capturedCount + 1;
      emit(state.copyWith(
        capturedCount: newCount,
        isCapturingFrame: false,
        pointCount: newCount * 1000,
      ));

      // Auto-trigger meshing after all shots captured
      if (newCount >= EnvConfig.captureCount) {
        add(const ScanMeshGenerationRequested());
      }
    } catch (e) {
      print('[ScanBloc] Capture error: $e');
      emit(state.copyWith(
        isCapturingFrame: false,
        status: ScanStatus.error,
        errorMessage: 'Capture failed: $e',
      ));
    }
  }

  // ── 3. Mesh + Texture Pipeline ─────────────────────────────────────────────

  Future<void> _onMeshGenerationRequested(
    ScanMeshGenerationRequested event,
    Emitter<ScanState> emit,
  ) async {
    print('[PIPELINE] ══════════════ START ══════════════');
    await _stopCamera();
    _inferenceIsolate.stop();

    emit(state.copyWith(
      status: ScanStatus.processing,
      processingProgress: 0.0,
      processingStep: ProcessingStep.aligningPointClouds,
      isCameraReady: false,
    ));

    final start = DateTime.now();

    try {
      _step(emit, ProcessingStep.generatingMesh, 0.15, start);

      final tRes = EnvConfig.meshThetaRes;
      final pRes = EnvConfig.meshPhiRes;
      final fLen = EnvConfig.focalLength;
      final size = EnvConfig.depthInputSize;

      // ── THE FIX: Create local variables so Dart doesn't capture `this` (ScanBloc) ──
      // ── 1. Pass the RGB Frames to the Carver ──
      final localMasks = List<List<bool>>.from(_allMasks);
      final localDepthMaps = List<Float32List>.from(_allDepthMaps);
      final localPoses = List<Matrix4>.from(_allPoses);
      final localFrames =
          List<Uint8List>.from(_capturedFrames); // Get the frames!

      final MeshData? mesh = await Isolate.run(() {
        // 1. Prepare the raw RGB arrays
        final decodedRgbFrames = <Uint8List>[];
        final int targetSize =
            size.toInt(); // Ensure it is an integer (e.g., 518)

        for (final frameBytes in localFrames) {
          // Decompress the JPEG
          final image = img.decodeImage(frameBytes);
          if (image == null) continue;

          // Resize the photo to perfectly match the Depth Map & Mask dimensions
          final resized =
              img.copyResize(image, width: targetSize, height: targetSize);

          // Extract the raw, flat RGB bytes so the Carver can map them instantly
          decodedRgbFrames.add(resized.getBytes(order: img.ChannelOrder.rgb));
        }

        // 2. Run the Depth Unprojection
        return SpaceCarver.carveAndMesh(
          masks: localMasks,
          depthMaps: localDepthMaps,
          cameraPoses: localPoses,
          rgbFrames: decodedRgbFrames, // Pass the RAW decoded pixels!
          focalLength: fLen,
          cx: size / 2.0,
          cy: size / 2.0,
          maskWidth: targetSize,
          maskHeight: targetSize,
          voxelResolution: 64,
          physicalSize: 1.0,
        );
      });

      if (mesh == null || mesh.vertexCount == 0) {
        throw Exception('Mesh generation produced no vertices.');
      }

      // ── 2. BYPASS TEXTURE MAPPING ──
      // We skip the texture mapper completely because our Splat Mesh
      // uses Vertex Colors! We generate tiny dummy images just to
      // satisfy the UI state without crashing.

      _step(emit, ProcessingStep.done, 1.0, start);

      final dummyImageBytes =
          Uint8List.fromList(img.encodeJpg(img.Image(width: 1, height: 1)));

      emit(state.copyWith(
        status: ScanStatus.meshReady,
        mesh: mesh,
        baseMapBytes: dummyImageBytes, // Dummy placeholder
        normalMapBytes: dummyImageBytes, // Dummy placeholder
        processingProgress: 1.0,
        processingStep: ProcessingStep.done,
      ));
    } catch (e, st) {
      print('[PIPELINE] ERROR: $e\n$st');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Processing failed: $e',
      ));
    }
  }

  // ── Data Management ────────────────────────────────────────────────────────

  Future<void> _onSaveRequested(
      ScanSaveRequested event, Emitter<ScanState> emit) async {
    if (state.mesh == null) return;
    emit(state.copyWith(status: ScanStatus.saving));
    try {
      final baseImg = img.decodeImage(state.baseMapBytes!)!;
      final thumb = img.copyResize(baseImg, width: 128, height: 128);
      final thumbBytes = Uint8List.fromList(
          img.encodeJpg(thumb, quality: EnvConfig.thumbnailQuality));

      // We no longer have a raw Point Cloud, so we just save the final Mesh vertices!
      final pointCloudBytes = state.mesh!.vertices.buffer.asUint8List();

      await _repository.saveScan(
        name: event.name,
        thumbnail: thumbBytes,
        baseMap: state.baseMapBytes!,
        normalMap: state.normalMapBytes!,
        pointCloud: pointCloudBytes, // Just saving the mesh structure now
        frameCount: state.capturedCount,
        faceCount: state.mesh!.faceCount,
        vertexCount: state.mesh!.vertexCount,
        edgeCount: state.mesh!.edgeCount,
        triangleCount: state.mesh!.triangleCount,
      );
      emit(state.copyWith(status: ScanStatus.meshReady));
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Save failed: $e',
      ));
    }
  }

  Future<void> _onExportRequested(
      ScanExportRequested event, Emitter<ScanState> emit) async {
    // Export logic goes here
  }

  Future<void> _onRescanRequested(
      ScanRescanRequested event, Emitter<ScanState> emit) async {
    await _stopCamera();
    _inferenceIsolate.stop();
    _capturedFrames.clear();
    _frameWidths.clear();
    _frameHeights.clear();

    // Wipe them out again
    _allMasks.clear();
    _allDepthMaps.clear();
    _allPoses.clear();

    emit(const ScanState());
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  ResolutionPreset _resolutionPreset(String s) {
    switch (s) {
      case 'max':
        return ResolutionPreset.max;
      case 'ultraHigh':
        return ResolutionPreset.ultraHigh;
      case 'veryHigh':
        return ResolutionPreset.veryHigh;
      case 'medium':
        return ResolutionPreset.medium;
      case 'low':
        return ResolutionPreset.low;
      default:
        return ResolutionPreset.high;
    }
  }

  Future<void> _stopCamera() async {
    try {
      await cameraController?.dispose();
      cameraController = null;
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await _stopCamera();
    _inferenceIsolate.stop();
    return super.close();
  }
}
