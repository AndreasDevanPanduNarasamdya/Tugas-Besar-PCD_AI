import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math.dart';

import '../ai/depth_estimator.dart';
import '../ai/segmentation_model.dart';
import '../ai/inference_isolate.dart';
import '../processing/frame_preprocessor.dart';
import '../processing/bilateral_filter.dart';
import '../processing/edge_detector.dart';
import '../processing/median_filter.dart';
import '../processing/sharpener.dart';
import '../reconstruction/point_cloud_builder.dart';
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

  final DepthEstimator _depthEstimator = DepthEstimator();
  final SegmentationModel _segmentationModel = SegmentationModel();
  final InferenceIsolate _inferenceIsolate = InferenceIsolate();
  final PointCloudBuilder _pointCloudBuilder = PointCloudBuilder();
  final MeshGenerator _meshGenerator = MeshGenerator();
  final TextureMapper _textureMapper = TextureMapper();
  final FramePreprocessor _framePreprocessor = FramePreprocessor();

  CameraController? _cameraController;
  int _frameCounter = 0;
  bool _isProcessingFrame = false;
  final List<Uint8List> _capturedFrames = [];
  final List<int> _frameWidths = [];
  final List<int> _frameHeights = [];

  static const int _depthFrameInterval = 3;
  static const int _maxCapturedFrames = 30;

  ScanBloc({
    required ScanRepository repository,
    required ObjExporter exporter,
  })  : _repository = repository,
        _exporter = exporter,
        super(const ScanState()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanStopped>(_onScanStopped);
    on<ScanFrameReceived>(_onFrameReceived);
    on<ScanMeshGenerationRequested>(_onMeshGenerationRequested);
    on<ScanRescanRequested>(_onRescanRequested);
    on<ScanSaveRequested>(_onSaveRequested);
    on<ScanExportRequested>(_onExportRequested);
    on<ScanProgressUpdated>(_onProgressUpdated);
  }

  // ── Camera getter for UI ─────────────────────────────────────────────────
  CameraController? get cameraController => _cameraController;

  // ── Start scan ───────────────────────────────────────────────────────────
  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<ScanState> emit,
  ) async {
    try {
      // Reset state
      _frameCounter = 0;
      _isProcessingFrame = false;
      _capturedFrames.clear();
      _frameWidths.clear();
      _frameHeights.clear();
      _pointCloudBuilder.clear();

      emit(state.copyWith(
        status: ScanStatus.scanning,
        coveragePercent: 0.0,
        pointCount: 0,
        frameCount: 0,
        errorMessage: null,
      ));

      // Start inference isolate
      await _inferenceIsolate.start();

      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        emit(state.copyWith(
          status: ScanStatus.error,
          errorMessage: 'No camera found on this device.',
        ));
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      emit(state.copyWith(isCameraReady: true));

      // Start real frame stream
      await _cameraController!.startImageStream((CameraImage frame) {
        add(ScanFrameReceived(cameraImage: frame));
      });
    } on CameraException catch (e) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Camera error: ${e.description}',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Failed to start scan: $e',
      ));
    }
  }

  // ── Process each camera frame ────────────────────────────────────────────
  Future<void> _onFrameReceived(
    ScanFrameReceived event,
    Emitter<ScanState> emit,
  ) async {
    if (state.status != ScanStatus.scanning) return;
    if (_isProcessingFrame) return;
    if (_pointCloudBuilder.isFull) return;

    _isProcessingFrame = true;
    _frameCounter++;

    try {
      final frame = event.cameraImage;

      // ── Convert YUV420 to RGB ──────────────────────────────────
      final rgbBytes = _framePreprocessor.yuv420ToRgb(
        frame.planes[0].bytes,
        frame.planes[1].bytes,
        frame.planes[2].bytes,
        frame.width,
        frame.height,
      );

      // ── Blur check — skip blurry frames ───────────────────────
      final isSharp = _framePreprocessor.isFrameSharp(
        rgbBytes,
        frame.width,
        frame.height,
      );
      if (!isSharp) {
        _isProcessingFrame = false;
        return;
      }

      // Store sharp frame for texture mapping
      if (_capturedFrames.length < _maxCapturedFrames) {
        _capturedFrames.add(rgbBytes);
        _frameWidths.add(frame.width);
        _frameHeights.add(frame.height);
      }

      // Only run heavy AI every Nth frame
      if (_frameCounter % _depthFrameInterval != 0) {
        _isProcessingFrame = false;
        return;
      }

      // ── Preprocess for AI models ───────────────────────────────
      final depthInput = _framePreprocessor.prepareForDepth(
        rgbBytes,
        frame.width,
        frame.height,
      );
      final segInput = _framePreprocessor.prepareForSegmentation(
        rgbBytes,
        frame.width,
        frame.height,
      );

// ── Run AI inference ───────────────────────────────────────
      final depthResult = await _inferenceIsolate.runDepth(depthInput);
      final segResult = await _inferenceIsolate.runSegmentation(segInput);

      if (depthResult.error != null || segResult.error != null) {
        _isProcessingFrame = false;
        return;
      }

      // DO NOT use the Median or Bilateral filters here!
      // Grab the raw output straight from the TFLite model.
      final rawDepthMap = depthResult.depthMap!;

      // ── Step 5: Add raw points to point cloud ───────────────
      _pointCloudBuilder.addFrame(
        depthMap: rawDepthMap,
        segMask: Uint8List(
            EnvConfig.segmentationInputSize * EnvConfig.segmentationInputSize)
          ..fillRange(0, 256 * 256, 255),
        rgbFrame: rgbBytes,
        cameraPose: Matrix4.identity(),
        focalLength: 500.0,
        cx: EnvConfig.depthInputSize / 2,
        cy: EnvConfig.depthInputSize / 2,
      );

      print("====== SCANNER STATUS ======");
      print("TOTAL POINTS IN MEMORY: ${_pointCloudBuilder.pointCount}");
      if (_pointCloudBuilder.pointCount > 0) {
        print("SAMPLE POINT 0: ${_pointCloudBuilder.points.first.position}");
      }
      print("============================");

      final coverage =
          (_pointCloudBuilder.pointCount / PointCloudBuilder.maxPoints * 100)
              .clamp(0.0, 100.0);
      add(ScanProgressUpdated(
          coveragePercent: coverage,
          pointCount: _pointCloudBuilder.pointCount));

      add(ScanProgressUpdated(
        coveragePercent: coverage,
        pointCount: _pointCloudBuilder.pointCount,
      ));
    } catch (e) {
      print('[ScanBloc] Frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ── Progress update ──────────────────────────────────────────────────────
  void _onProgressUpdated(
    ScanProgressUpdated event,
    Emitter<ScanState> emit,
  ) {
    emit(state.copyWith(
      coveragePercent: event.coveragePercent,
      pointCount: event.pointCount,
      frameCount: _frameCounter,
    ));
  }

  // ── Stop scan ────────────────────────────────────────────────────────────
  Future<void> _onScanStopped(
    ScanStopped event,
    Emitter<ScanState> emit,
  ) async {
    await _stopCamera();
    _inferenceIsolate.stop();
    emit(state.copyWith(status: ScanStatus.idle, isCameraReady: false));
  }

  // ── Generate mesh ────────────────────────────────────────────────────────
  Future<void> _onMeshGenerationRequested(
    ScanMeshGenerationRequested event,
    Emitter<ScanState> emit,
  ) async {
    await _stopCamera();
    _inferenceIsolate.stop();

    if (_pointCloudBuilder.pointCount < 100) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Not enough points captured. Try scanning again.',
      ));
      return;
    }

    emit(state.copyWith(
      status: ScanStatus.processing,
      processingProgress: 0.0,
    ));

    try {
      // ── Generate mesh from point cloud ────────────────────────
      emit(state.copyWith(processingProgress: 0.1));
      final mesh = _meshGenerator.generate(_pointCloudBuilder.points);

      if (mesh.vertexCount == 0) {
        emit(state.copyWith(
          status: ScanStatus.error,
          errorMessage: 'Mesh generation produced no vertices. Rescan.',
        ));
        return;
      }

      // ── Generate base color texture ───────────────────────────
      emit(state.copyWith(processingProgress: 0.35));
      var baseMap = _textureMapper.generateBaseColorMap(
        mesh,
        _capturedFrames,
        _frameWidths,
        _frameHeights,
      );

      // ── Sharpen base map ──────────────────────────────────────
      emit(state.copyWith(processingProgress: 0.55));
      baseMap = Sharpener.apply(
        source: baseMap,
        strength: 0.5,
        blurRadius: 1,
      );

      // ── Generate normal map ───────────────────────────────────
      emit(state.copyWith(processingProgress: 0.7));
      var normalMap = _textureMapper.generateNormalMap(mesh);

      // ── Sharpen normal map ────────────────────────────────────
      emit(state.copyWith(processingProgress: 0.82));
      normalMap = Sharpener.apply(
        source: normalMap,
        strength: 0.3,
        blurRadius: 1,
      );

      // ── Encode textures to PNG bytes ──────────────────────────
      emit(state.copyWith(processingProgress: 0.92));
      final baseMapBytes = Uint8List.fromList(img.encodePng(baseMap));
      final normalMapBytes = Uint8List.fromList(img.encodePng(normalMap));

      emit(state.copyWith(
        status: ScanStatus.meshReady,
        mesh: mesh,
        baseMapBytes: baseMapBytes,
        normalMapBytes: normalMapBytes,
        processingProgress: 1.0,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Mesh generation failed: $e',
      ));
    }
  }

  // ── Save scan ────────────────────────────────────────────────────────────
  Future<void> _onSaveRequested(
    ScanSaveRequested event,
    Emitter<ScanState> emit,
  ) async {
    if (state.mesh == null ||
        state.baseMapBytes == null ||
        state.normalMapBytes == null) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Nothing to save — scan first.',
      ));
      return;
    }

    emit(state.copyWith(status: ScanStatus.saving));

    try {
      // Serialize point cloud
      final pointCloudBytes =
          _pointCloudBuilder.toFloat32List().buffer.asUint8List();

      // Generate thumbnail from base map (downscale to 128x128)
      final baseImg = img.decodeImage(state.baseMapBytes!)!;
      final thumb = img.copyResize(baseImg, width: 128, height: 128);
      final thumbBytes = Uint8List.fromList(img.encodeJpg(thumb, quality: 60));

      final mesh = state.mesh!;

      await _repository.saveScan(
        name: event.name,
        thumbnail: thumbBytes,
        baseMap: state.baseMapBytes!,
        normalMap: state.normalMapBytes!,
        pointCloud: pointCloudBytes,
        frameCount: _frameCounter,
        faceCount: mesh.faceCount,
        vertexCount: mesh.vertexCount,
        edgeCount: mesh.edgeCount,
        triangleCount: mesh.triangleCount,
      );

      emit(state.copyWith(status: ScanStatus.meshReady));
      print('[ScanBloc] Scan saved: ${event.name}');
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Save failed: $e',
      ));
    }
  }

  // ── Export scan ──────────────────────────────────────────────────────────
  Future<void> _onExportRequested(
    ScanExportRequested event,
    Emitter<ScanState> emit,
  ) async {
    if (state.mesh == null ||
        state.baseMapBytes == null ||
        state.normalMapBytes == null) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Nothing to export — scan first.',
      ));
      return;
    }

    emit(state.copyWith(status: ScanStatus.exporting));

    try {
      final zipPath = await _exporter.export(
        mesh: state.mesh!,
        baseMapBytes: state.baseMapBytes!,
        normalMapBytes: state.normalMapBytes!,
        scanName: event.scanId,
      );

      await _repository.updateExportPath(event.scanId, zipPath);
      await _exporter.share(zipPath);

      emit(state.copyWith(
        status: ScanStatus.meshReady,
        exportPath: zipPath,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Export failed: $e',
      ));
    }
  }

  // ── Rescan ───────────────────────────────────────────────────────────────
  Future<void> _onRescanRequested(
    ScanRescanRequested event,
    Emitter<ScanState> emit,
  ) async {
    await _stopCamera();
    _inferenceIsolate.stop();
    _pointCloudBuilder.clear();
    _capturedFrames.clear();
    _frameWidths.clear();
    _frameHeights.clear();
    _frameCounter = 0;
    _isProcessingFrame = false;
    emit(const ScanState());
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Future<void> _stopCamera() async {
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      print('[ScanBloc] Camera stop error: $e');
    }
  }

  @override
  Future<void> close() async {
    await _stopCamera();
    _inferenceIsolate.stop();
    _depthEstimator.dispose();
    _segmentationModel.dispose();
    return super.close();
  }
}
