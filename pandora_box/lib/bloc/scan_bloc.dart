import 'dart:async';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math.dart';

import '../ai/inference_isolate.dart';
import '../processing/frame_preprocessor.dart';
import '../processing/object_segmenter.dart';
import '../processing/space_carver.dart';
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

  final List<Uint8List> _capturedFrames = [];
  final List<int> _frameWidths = [];
  final List<int> _frameHeights = [];

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

  void _step(Emitter<ScanState> emit, ProcessingStep step, double progress,
      DateTime start,
      {String? extraNote}) {
    final ms = DateTime.now().difference(start).inMilliseconds;
    final note = extraNote != null ? ' — $extraNote' : '';
    print(
        '[PIPELINE +${ms}ms] ${step.label}$note  (${(progress * 100).toInt()}%)');
    emit(state.copyWith(processingStep: step, processingProgress: progress));
  }

  Future<void> _onScanStarted(
      ScanStarted event, Emitter<ScanState> emit) async {
    _capturedFrames.clear();
    _frameWidths.clear();
    _frameHeights.clear();
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
    } catch (e) {
      emit(state.copyWith(
          status: ScanStatus.error, errorMessage: 'Camera failed: $e'));
    }
  }

  Future<void> _onPhotoCaptured(
      ScanPhotoCaptured event, Emitter<ScanState> emit) async {
    if (state.capturedCount >= EnvConfig.captureCount ||
        state.isCapturingFrame ||
        cameraController == null) return;
    emit(state.copyWith(isCapturingFrame: true));

    try {
      final xFile = await cameraController!.takePicture();
      final rawBytes = await xFile.readAsBytes();
      final image = img.decodeImage(rawBytes);
      if (image == null) throw Exception('Failed to decode');

      final w = image.width, h = image.height;
      final rgb = image.getBytes(order: img.ChannelOrder.rgb);
      _capturedFrames.add(rawBytes);
      _frameWidths.add(w);
      _frameHeights.add(h);

      final depthInput = _framePreprocessor.prepareForDepth(rgb, w, h);
      final depthResult = await _inferenceIsolate.runDepth(depthInput);
      if (depthResult.error != null) throw Exception(depthResult.error);

      final depthMap = depthResult.depthMap!;
      double centerSum = 0;
      int centerCount = 0;
      final int cx = EnvConfig.depthInputSize ~/ 2,
          cy = EnvConfig.depthInputSize ~/ 2;

      for (int y = cy - 15; y <= cy + 15; y++) {
        for (int x = cx - 15; x <= cx + 15; x++) {
          int idx = y * EnvConfig.depthInputSize + x;
          if (idx >= 0 && idx < depthMap.length) {
            centerSum += depthMap[idx];
            centerCount++;
          }
        }
      }

      final rawDepth = centerCount > 0 ? (centerSum / centerCount) : 0.6;
      final metricDepth = 0.3 + (1.0 - rawDepth) * 3.0;
      final angleRad =
          (state.capturedCount * (360.0 / EnvConfig.captureCount)) *
              (math.pi / 180.0);

      final pose = Matrix4.rotationY(angleRad)
        ..translate(0.0, 0.0, -metricDepth);

      final validMask = ObjectSegmenter.generateMask(
        depthMap: depthMap,
        width: EnvConfig.depthInputSize,
        height: EnvConfig.depthInputSize,
        depthTolerance: 0.08,
      );

      _allMasks.add(validMask);
      _allDepthMaps.add(depthMap);
      _allPoses.add(pose);

      final newCount = state.capturedCount + 1;
      emit(state.copyWith(
          capturedCount: newCount,
          isCapturingFrame: false,
          pointCount: newCount * 1000));

      if (newCount >= EnvConfig.captureCount)
        add(const ScanMeshGenerationRequested());
    } catch (e) {
      emit(state.copyWith(
          isCapturingFrame: false,
          status: ScanStatus.error,
          errorMessage: 'Capture failed: $e'));
    }
  }

  Future<void> _onMeshGenerationRequested(
      ScanMeshGenerationRequested event, Emitter<ScanState> emit) async {
    await _stopCamera();
    _inferenceIsolate.stop();
    emit(state.copyWith(
        status: ScanStatus.processing,
        processingProgress: 0.0,
        processingStep: ProcessingStep.aligningPointClouds,
        isCameraReady: false));
    final start = DateTime.now();

    try {
      _step(emit, ProcessingStep.generatingMesh, 0.15, start);

      final fLen = EnvConfig.focalLength;
      final size = EnvConfig.depthInputSize;

      final localMasks = List<List<bool>>.from(_allMasks);
      final localDepthMaps = List<Float32List>.from(_allDepthMaps);
      final localPoses = List<Matrix4>.from(_allPoses);
      final localFrames = List<Uint8List>.from(_capturedFrames);

      final MeshData? mesh = await Isolate.run(() {
        final decodedRgbFrames = <Uint8List>[];
        final int targetSize = size.toInt();

        for (final frameBytes in localFrames) {
          final image = img.decodeImage(frameBytes);
          if (image == null) continue;
          final resized =
              img.copyResize(image, width: targetSize, height: targetSize);
          decodedRgbFrames.add(resized.getBytes(order: img.ChannelOrder.rgb));
        }

        return SpaceCarver.carveAndMesh(
          masks: localMasks,
          depthMaps: localDepthMaps,
          cameraPoses: localPoses,
          rgbFrames: decodedRgbFrames,
          focalLength: fLen,
          cx: size / 2.0,
          cy: size / 2.0,
          maskWidth: targetSize,
          maskHeight: targetSize,
          voxelResolution: 64,
          physicalSize: 1.0,
        );
      });

      if (mesh == null || mesh.vertexCount == 0)
        throw Exception('Mesh generation produced no vertices.');

      _step(emit, ProcessingStep.done, 1.0, start);
      final dummyImageBytes =
          Uint8List.fromList(img.encodeJpg(img.Image(width: 1, height: 1)));

      emit(state.copyWith(
        status: ScanStatus.meshReady,
        mesh: mesh,
        baseMapBytes: dummyImageBytes,
        normalMapBytes: dummyImageBytes,
        processingProgress: 1.0,
        processingStep: ProcessingStep.done,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: ScanStatus.error, errorMessage: 'Processing failed: $e'));
    }
  }

  Future<void> _onSaveRequested(
      ScanSaveRequested event, Emitter<ScanState> emit) async {
    if (state.mesh == null) return;
    emit(state.copyWith(status: ScanStatus.saving));
    try {
      // Generate a simple gradient thumbnail since we have no real texture yet
      final thumbImg = img.Image(width: 128, height: 128);
      img.fill(thumbImg, color: img.ColorRgb8(30, 30, 30));
      final thumbBytes =
          Uint8List.fromList(img.encodeJpg(thumbImg, quality: 60));

      final pointCloudBytes = state.mesh!.vertices.buffer.asUint8List();

      // base/normal maps — use dummy until texture pipeline is wired
      final dummyBytes =
          Uint8List.fromList(img.encodeJpg(img.Image(width: 1, height: 1)));

      await _repository.saveScan(
        name: event.name,
        thumbnail: thumbBytes,
        baseMap: state.baseMapBytes ?? dummyBytes,
        normalMap: state.normalMapBytes ?? dummyBytes,
        pointCloud: pointCloudBytes,
        frameCount: state.capturedCount,
        faceCount: state.mesh!.faceCount,
        vertexCount: state.mesh!.vertexCount,
        edgeCount: state.mesh!.edgeCount,
        triangleCount: state.mesh!.triangleCount,
      );
      emit(state.copyWith(status: ScanStatus.meshReady));
    } catch (e) {
      emit(state.copyWith(
          status: ScanStatus.error, errorMessage: 'Save failed: $e'));
    }
  }

  Future<void> _onExportRequested(
      ScanExportRequested event, Emitter<ScanState> emit) async {}

  Future<void> _onRescanRequested(
      ScanRescanRequested event, Emitter<ScanState> emit) async {
    await _stopCamera();
    _inferenceIsolate.stop();
    _capturedFrames.clear();
    _frameWidths.clear();
    _frameHeights.clear();
    _allMasks.clear();
    _allDepthMaps.clear();
    _allPoses.clear();
    emit(const ScanState());
  }

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
