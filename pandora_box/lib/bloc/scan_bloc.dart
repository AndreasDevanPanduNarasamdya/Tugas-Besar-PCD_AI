import 'dart:async';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math.dart';
import '../ai/depth_estimator.dart';
import '../ai/segmentation_model.dart';
import '../ai/inference_isolate.dart';
import '../processing/frame_preprocessor.dart';
import '../processing/edge_detector.dart';
import '../processing/sharpener.dart';
import '../reconstruction/point_cloud_builder.dart';
import '../reconstruction/mesh_generator.dart';
import '../reconstruction/texture_mapper.dart';
import '../storage/scan_repository.dart';
import '../export/obj_exporter.dart';
import '../config/env_config.dart';

part 'scan_event.dart';
part 'scan_state.dart';

// ── Isolate payload — plain data only, no Flutter/platform objects ────────────
// Passed into Isolate.run() so everything must be sendable across isolate boundary.

class _PipelineInput {
  final List<dynamic> points; // PointCloudBuilder.points snapshot
  final List<Uint8List> frames; // captured RGB frames
  final List<int> widths;
  final List<int> heights;
  const _PipelineInput(this.points, this.frames, this.widths, this.heights);
}

class _PipelineOutput {
  final MeshData mesh;
  final Uint8List baseMapBytes;
  final Uint8List normalMapBytes;
  const _PipelineOutput(this.mesh, this.baseMapBytes, this.normalMapBytes);
}

// ─────────────────────────────────────────────────────────────────────────────

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ScanRepository _repository;
  final ObjExporter _exporter;

  final DepthEstimator _depthEstimator = DepthEstimator();
  final SegmentationModel _segmentationModel = SegmentationModel();
  final InferenceIsolate _inferenceIsolate = InferenceIsolate();
  final PointCloudBuilder _pointCloudBuilder = PointCloudBuilder();
  final FramePreprocessor _framePreprocessor = FramePreprocessor();

  CameraController? _cameraController;
  int _frameCounter = 0;
  bool _isProcessingFrame = false;
  final List<Uint8List> _capturedFrames = [];
  final List<int> _frameWidths = [];
  final List<int> _frameHeights = [];

  // Process depth AI every 3rd frame — keeps CPU headroom for UI
  static const int _depthFrameInterval = 3;
  // Cap frames so texture isolate doesn't OOM on low-end devices
  static const int _maxCapturedFrames = 30;

  ScanBloc({
    required ScanRepository repository,
    required ObjExporter exporter,
  })  : _repository = repository,
        _exporter = exporter,
        super(const ScanState()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanStopped>(_onScanStopped);
    on<ScanFrameReceived>(_onFrameReceived,
        // Drop frames that arrive while a previous one is still in the queue.
        // This prevents the bloc event queue from growing unbounded on fast cameras.
        transformer: (events, mapper) =>
            events.where((_) => !_isProcessingFrame).asyncExpand(mapper));
    on<ScanMeshGenerationRequested>(_onMeshGenerationRequested);
    on<ScanRescanRequested>(_onRescanRequested);
    on<ScanSaveRequested>(_onSaveRequested);
    on<ScanExportRequested>(_onExportRequested);
    on<ScanProgressUpdated>(_onProgressUpdated);
  }

  CameraController? get cameraController => _cameraController;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Emit a new processing step and log to console with elapsed ms.
  void _step(
    Emitter<ScanState> emit,
    ProcessingStep step,
    double progress,
    DateTime pipelineStart, {
    String? extraNote,
  }) {
    final elapsed = DateTime.now().difference(pipelineStart).inMilliseconds;
    final note = extraNote != null ? ' — $extraNote' : '';
    print(
        '[PIPELINE +${elapsed}ms] ${step.label}$note  (${(progress * 100).toInt()}%)');
    emit(state.copyWith(
      processingStep: step,
      processingProgress: progress,
    ));
  }

  // ── ScanStarted ────────────────────────────────────────────────────────────

  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<ScanState> emit,
  ) async {
    print('[ScanBloc] ── ScanStarted ──────────────────────────');

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
      processingStep: ProcessingStep.idle,
    ));

    try {
      print('[ScanBloc] Starting inference isolate...');
      await _inferenceIsolate.start();
      print('[ScanBloc] Inference isolate ready.');

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('[ScanBloc] ERROR: no cameras found.');
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
      print(
          '[ScanBloc] Using camera: ${backCamera.name} (${backCamera.lensDirection})');

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // medium = faster inference, lower memory
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      print('[ScanBloc] Camera initialized — '
          '${_cameraController!.value.previewSize}');

      emit(state.copyWith(isCameraReady: true));

      await _cameraController!.startImageStream((CameraImage frame) {
        add(ScanFrameReceived(cameraImage: frame));
      });
      print('[ScanBloc] Image stream started.');
    } on CameraException catch (e) {
      print('[ScanBloc] CameraException: ${e.code} — ${e.description}');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Camera error: ${e.description}',
      ));
    } catch (e, st) {
      print('[ScanBloc] ScanStarted error: $e\n$st');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Failed to start scan: $e',
      ));
    }
  }

  // ── ScanFrameReceived ──────────────────────────────────────────────────────

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

      // ── 1. YUV → RGB ───────────────────────────────────────────
      // ── 1. YUV → RGB (USE THE SIZE HELPER) ──────────────────────
      final (rgbBytes, actualW, actualH) =
          _framePreprocessor.yuv420ToRgbWithSize(
        frame.planes[0].bytes,
        frame.planes[1].bytes,
        frame.planes[2].bytes,
        frame.width,
        frame.height,
      );

      // ── 2. Blur check ───────────────────────────────────────────
      final isSharp = _framePreprocessor.isFrameSharp(
        rgbBytes,
        actualW, // USE ACTUAL WIDTH
        actualH, // USE ACTUAL HEIGHT
      );
      if (!isSharp) {
        if (_frameCounter % 30 == 0) print('[ScanBloc] Frame skipped');
        return;
      }

      // ── 3. Store frame for texture mapping ─────────────────────
      if (_capturedFrames.length < _maxCapturedFrames) {
        _capturedFrames.add(rgbBytes);
        _frameWidths.add(actualW); // Store actual size
        _frameHeights.add(actualH); // Store actual size
      }

      if (_frameCounter % _depthFrameInterval != 0) return;

      // ── 5. Prepare AI inputs ────────────────────────────────────
      final depthInput = _framePreprocessor.prepareForDepth(
        rgbBytes,
        actualW, // USE ACTUAL WIDTH
        actualH, // USE ACTUAL HEIGHT
      );
      final segInput = _framePreprocessor.prepareForSegmentation(
        rgbBytes,
        actualW, // USE ACTUAL WIDTH
        actualH, // USE ACTUAL HEIGHT
      );

      // ── 6. Run depth + segmentation inference ──────────────────
      final depthResult = await _inferenceIsolate.runDepth(depthInput);
      final segResult = await _inferenceIsolate.runSegmentation(segInput);

      if (depthResult.error != null || segResult.error != null) {
        print('[ScanBloc] Inference error — depth: ${depthResult.error}  '
            'seg: ${segResult.error}');
        return;
      }

      final rawDepthMap = depthResult.depthMap!;
      final segMask = segResult.segmentationMask!;

      // ── 7. Depth sanity check ────────────────────────────────────
      double maxDepth = 0.0;
      for (final v in rawDepthMap) if (v > maxDepth) maxDepth = v;
      if (_frameCounter % (_depthFrameInterval * 5) == 0) {
        print('[ScanBloc] Frame #$_frameCounter — maxDepth: '
            '${maxDepth.toStringAsFixed(4)}  '
            'frames captured: ${_capturedFrames.length}  '
            'points: ${_pointCloudBuilder.pointCount}');
      }
      if (maxDepth == 0.0) {
        print(
            '[ScanBloc] WARNING: depth map is all zeros at frame #$_frameCounter');
        return;
      }

      // ── 8. Edge-aware valid mask ─────────────────────────────────
      final validMask = EdgeDetector.generateValidMask(
        depthMap: rawDepthMap,
        width: EnvConfig.depthInputSize,
        height: EnvConfig.depthInputSize,
        edgeThreshold: 0.05,
      );

      // ── 9. Add to point cloud ────────────────────────────────────
      _pointCloudBuilder.addFrameWithMask(
        depthMap: rawDepthMap,
        segMask: segMask,
        validMask: validMask,
        rgbFrame: rgbBytes,
        cameraPose: Matrix4.identity(),
        focalLength: 500.0,
        cx: EnvConfig.depthInputSize / 2.0,
        cy: EnvConfig.depthInputSize / 2.0,
        depthWidth: EnvConfig.depthInputSize,
        depthHeight: EnvConfig.depthInputSize,
      );

      // ── 10. Update UI progress ───────────────────────────────────
      final coverage =
          (_pointCloudBuilder.pointCount / PointCloudBuilder.maxPoints * 100)
              .clamp(0.0, 100.0);
      add(ScanProgressUpdated(
        coveragePercent: coverage,
        pointCount: _pointCloudBuilder.pointCount,
      ));
    } catch (e, st) {
      print('[ScanBloc] Frame #$_frameCounter error: $e\n$st');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ── ScanProgressUpdated ────────────────────────────────────────────────────

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

  // ── ScanStopped ────────────────────────────────────────────────────────────

  Future<void> _onScanStopped(
    ScanStopped event,
    Emitter<ScanState> emit,
  ) async {
    print('[ScanBloc] ── ScanStopped ─────────────────────────────');
    await _stopCamera();
    _inferenceIsolate.stop();
    emit(state.copyWith(status: ScanStatus.idle, isCameraReady: false));
  }

  // ── ScanMeshGenerationRequested ───────────────────────────────────────────

  Future<void> _onMeshGenerationRequested(
    ScanMeshGenerationRequested event,
    Emitter<ScanState> emit,
  ) async {
    print('[PIPELINE] ══════════════ START ══════════════');
    print('[PIPELINE] Points collected: ${_pointCloudBuilder.pointCount}');
    print('[PIPELINE] Frames captured : ${_capturedFrames.length}');

    await _stopCamera();
    _inferenceIsolate.stop();

    emit(state.copyWith(
      status: ScanStatus.processing,
      coveragePercent: 100,
      processingProgress: 0.0,
      processingStep: ProcessingStep.generatingMesh,
      isCameraReady: false,
    ));

    final pipelineStart = DateTime.now();

    try {
      // ══════════════════════════════════════════════════════════
      // STAGE 1 — Point cloud voxel-downsample + Mesh Generation
      //
      // WHY DOWNSAMPLE:
      //   Raw point cloud from PointCloudBuilder can hold up to maxPoints
      //   (e.g. 5000). MeshGenerator uses Delaunay/BallPivoting which is
      //   O(n²) in the worst case — 5000 pts → ~935k faces, making texture
      //   mapping take minutes. Voxel-downsampling to ~1500 pts first gets
      //   faces down to ~20-40k, which textures in 2-5s instead of 60-120s.
      // ══════════════════════════════════════════════════════════
      _step(emit, ProcessingStep.generatingMesh, 0.05, pipelineStart);
      final meshStart = DateTime.now();

      final rawPoints = _pointCloudBuilder.points.toList();
      print('[PIPELINE] Raw point count: ${rawPoints.length}');

      // ── Voxel downsample before mesh gen ─────────────────────
      // Target: 1500 points max. Keeps mesh manageable on mobile.
      const int _targetPoints = 10000;
      final pointsList = rawPoints.length > _targetPoints
          ? _voxelDownsample(rawPoints, _targetPoints)
          : rawPoints;
      print('[PIPELINE] After downsample: ${pointsList.length} points '
          '(was ${rawPoints.length})');

      final mesh = await Isolate.run(() {
        final generator = MeshGenerator();

        // This satisfies the compiler AND the runtime.
        // Dart recognizes 'List.from<T>' as a proper factory constructor
        // instead of a "useless" manual type-cast.
        final typedPoints = List<PointCloudPoint>.from(pointsList);

        return generator.generate(typedPoints);
      });

      final meshMs = DateTime.now().difference(meshStart).inMilliseconds;
      print('[PIPELINE] Mesh done — ${meshMs}ms  '
          'v:${mesh.vertexCount}  f:${mesh.faceCount}  '
          'e:${mesh.edgeCount}  t:${mesh.triangleCount}');

      // ── Sanity checks ─────────────────────────────────────────
      if (mesh.vertexCount == 0) {
        print('[PIPELINE] ERROR: mesh has 0 vertices — aborting.');
        emit(state.copyWith(
          status: ScanStatus.error,
          errorMessage: 'Mesh generation produced no vertices.\n'
              'Try scanning with more frames or better lighting.',
        ));
        return;
      }

      // Warn if mesh is still very dense — texture step will be slow
      if (mesh.faceCount > 80000) {
        print('[PIPELINE] WARNING: mesh has ${mesh.faceCount} faces — '
            'texture mapping may be slow. Consider lowering _targetPoints.');
      }

      _step(emit, ProcessingStep.generatingMesh, 0.30, pipelineStart,
          extraNote: '${meshMs}ms  ${mesh.faceCount}f');

      // ══════════════════════════════════════════════════════════
      // STAGE 2 — Texture mapping + sharpening  (0.30 → 0.85)
      // Both steps combined in ONE isolate to avoid a second
      // spawn overhead (~100ms saved vs two separate Isolate.run).
      // ══════════════════════════════════════════════════════════
      _step(emit, ProcessingStep.mappingTextures, 0.32, pipelineStart);
      final textureStart = DateTime.now();

      // Snapshot lists before entering the isolate — isolates cannot
      // read mutable state from the parent.
      final framesList = List<Uint8List>.from(_capturedFrames);
      final widthsList = List<int>.from(_frameWidths);
      final heightsList = List<int>.from(_frameHeights);
      print(
          '[PIPELINE] Sending ${framesList.length} frames to texture isolate...');

      final textures = await Isolate.run(() {
        final mapper = TextureMapper();
        final base = mapper.generateBaseColorMap(
            mesh, framesList, widthsList, heightsList);
        final normal = mapper.generateNormalMap(mesh);
        // Sharpening inside the same isolate — no extra spawn cost
        return {
          'base': Sharpener.apply(source: base, strength: 0.5, blurRadius: 1),
          'normal':
              Sharpener.apply(source: normal, strength: 0.3, blurRadius: 1),
        };
      });

      final textureMs = DateTime.now().difference(textureStart).inMilliseconds;
      print('[PIPELINE] Texture + sharpening done — ${textureMs}ms');
      _step(emit, ProcessingStep.mappingTextures, 0.85, pipelineStart,
          extraNote: '${textureMs}ms');

      // ══════════════════════════════════════════════════════════
      // STAGE 3 — JPEG encoding  (0.85 → 0.98)
      // Also in isolate: img.encodeJpg is synchronous and CPU-heavy.
      // ══════════════════════════════════════════════════════════
      _step(emit, ProcessingStep.sharpeningAndEncoding, 0.86, pipelineStart);
      final encStart = DateTime.now();

      final encoded = await Isolate.run(() => {
            'base': Uint8List.fromList(
                img.encodeJpg(textures['base']!, quality: 75)),
            'normal': Uint8List.fromList(
                img.encodeJpg(textures['normal']!, quality: 75)),
          });

      final encMs = DateTime.now().difference(encStart).inMilliseconds;
      print('[PIPELINE] Encoding done — ${encMs}ms  '
          'base: ${(encoded['base']!.length / 1024).toStringAsFixed(1)}KB  '
          'normal: ${(encoded['normal']!.length / 1024).toStringAsFixed(1)}KB');

      // ══════════════════════════════════════════════════════════
      // DONE
      // ══════════════════════════════════════════════════════════
      final totalMs = DateTime.now().difference(pipelineStart).inMilliseconds;
      print('[PIPELINE] ══════════════ DONE ══════════════');
      print('[PIPELINE] Total: ${totalMs}ms  '
          '(mesh: ${meshMs}ms  texture: ${textureMs}ms  enc: ${encMs}ms)');

      emit(state.copyWith(
        status: ScanStatus.meshReady,
        mesh: mesh,
        baseMapBytes: encoded['base'],
        normalMapBytes: encoded['normal'],
        processingProgress: 1.0,
        processingStep: ProcessingStep.done,
      ));
    } on IsolateSpawnException catch (e, st) {
      // Isolate couldn't even start — usually OOM
      print('[PIPELINE] IsolateSpawnException: $e\n$st');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Not enough memory to process. Try closing other apps.',
      ));
    } catch (e, st) {
      final step = state.processingStep.label;
      print('[PIPELINE] ERROR during "$step": $e\n$st');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Failed during "$step":\n$e',
      ));
    }
  }

  // ── ScanSaveRequested ──────────────────────────────────────────────────────

  Future<void> _onSaveRequested(
    ScanSaveRequested event,
    Emitter<ScanState> emit,
  ) async {
    print('[ScanBloc] ── ScanSaveRequested: "${event.name}" ──');

    if (state.mesh == null ||
        state.baseMapBytes == null ||
        state.normalMapBytes == null) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Nothing to save — complete a scan first.',
      ));
      return;
    }

    emit(state.copyWith(status: ScanStatus.saving));

    try {
      // Thumbnail: decode → resize to 128×128 → re-encode at low quality
      // Done on main isolate — small image, fast enough
      final baseImg = img.decodeImage(state.baseMapBytes!)!;
      final thumb = img.copyResize(baseImg, width: 128, height: 128);
      final thumbBytes = Uint8List.fromList(img.encodeJpg(thumb, quality: 60));
      print('[ScanBloc] Thumbnail generated: ${thumbBytes.length} bytes');

      final pointCloudBytes =
          _pointCloudBuilder.toFloat32List().buffer.asUint8List();
      print('[ScanBloc] Point cloud serialized: '
          '${(pointCloudBytes.length / 1024).toStringAsFixed(1)}KB');

      final mesh = state.mesh!;
      final id = await _repository.saveScan(
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

      print('[ScanBloc] Saved successfully — id: $id');
      emit(state.copyWith(status: ScanStatus.meshReady));
    } catch (e, st) {
      print('[ScanBloc] Save error: $e\n$st');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Save failed: $e',
      ));
    }
  }

  // ── ScanExportRequested ────────────────────────────────────────────────────

  Future<void> _onExportRequested(
    ScanExportRequested event,
    Emitter<ScanState> emit,
  ) async {
    print('[ScanBloc] ── ScanExportRequested: ${event.scanId} ──');

    if (state.mesh == null ||
        state.baseMapBytes == null ||
        state.normalMapBytes == null) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Nothing to export — complete a scan first.',
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
      print('[ScanBloc] Export written to: $zipPath');

      await _repository.updateExportPath(event.scanId, zipPath);
      await _exporter.share(zipPath);

      emit(state.copyWith(
        status: ScanStatus.meshReady,
        exportPath: zipPath,
      ));
    } catch (e, st) {
      print('[ScanBloc] Export error: $e\n$st');
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Export failed: $e',
      ));
    }
  }

  // ── ScanRescanRequested ────────────────────────────────────────────────────

  Future<void> _onRescanRequested(
    ScanRescanRequested event,
    Emitter<ScanState> emit,
  ) async {
    print('[ScanBloc] ── ScanRescanRequested ─────────────────────');
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

  // ── Voxel downsampling ───────────────────────────────────────────────────
  // Reduces point count before mesh generation to prevent face explosion.
  // Groups points into a 3D grid of voxels and keeps one representative
  // point (the centroid) per occupied voxel.
  //
  // [points]  — your PointCloudPoint list (needs .position: Vector3)
  // [target]  — desired output count (not exact, but close)
  List<dynamic> _voxelDownsample(List<dynamic> points, int target) {
    if (points.isEmpty || points.length <= target) return points;

    // Find bounding box
    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = -double.infinity,
        maxY = -double.infinity,
        maxZ = -double.infinity;
    for (final p in points) {
      final v = p.position as Vector3;
      if (v.x < minX) minX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.z < minZ) minZ = v.z;
      if (v.x > maxX) maxX = v.x;
      if (v.y > maxY) maxY = v.y;
      if (v.z > maxZ) maxZ = v.z;
    }

    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final rangeZ = maxZ - minZ;
    final maxRange = math.max(rangeX, math.max(rangeY, rangeZ));

    if (maxRange == 0) return points.take(target).toList();

    // Voxel size chosen so we get roughly [target] occupied cells
    // from [points.length] input points
    // Replace the voxelSize calculation in _voxelDownsample with this:
    final ratio = points.length / target;
    // Ensure voxelSize is never too large (prevents the "flat 34 point" bug)
    final double voxelSize = 0.02;

    // Bucket points into voxels, keep one per voxel
    final Map<String, dynamic> voxelMap = {};
    for (final p in points) {
      final v = p.position as Vector3;
      final ix = ((v.x - minX) / voxelSize).floor();
      final iy = ((v.y - minY) / voxelSize).floor();
      final iz = ((v.z - minZ) / voxelSize).floor();
      final key = '$ix,$iy,$iz';
      voxelMap.putIfAbsent(key, () => p);
    }

    final result = voxelMap.values.toList();
    print('[PIPELINE] Voxel downsample: ${points.length} → ${result.length} '
        '(voxelSize=${voxelSize.toStringAsFixed(4)})');
    return result;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _stopCamera() async {
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
          print('[ScanBloc] Image stream stopped.');
        }
        await _cameraController!.dispose();
        _cameraController = null;
        print('[ScanBloc] Camera disposed.');
      }
    } catch (e) {
      print('[ScanBloc] Camera stop error (safe to ignore): $e');
    }
  }

  @override
  Future<void> close() async {
    print('[ScanBloc] ── close() ──────────────────────────────────');
    await _stopCamera();
    _inferenceIsolate.stop();
    _depthEstimator.dispose();
    _segmentationModel.dispose();
    return super.close();
  }
}
