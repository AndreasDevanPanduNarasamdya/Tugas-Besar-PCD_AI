import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../reconstruction/mesh_generator.dart';
import 'package:pandora_box/storage/scan_model.dart';

part 'scan_event.dart';
part 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  CameraController? _cameraController;
  Timer? _progressTimer;
  double _fakeProgress = 0;

  // -- Replace these stubs with your real services --
  // final DepthEstimator _depthEstimator;
  // final SegmentationModel _segModel;
  // final PointCloudBuilder _pointCloudBuilder;
  // final InferenceIsolate _inferenceIsolate;

  ScanBloc() : super(const ScanState()) {
    // Standard initialization
    on<ScanStarted>(_onScanStarted);
    on<ScanStopped>(_onScanStopped);
    on<ScanMeshGenerationRequested>(_onMeshGenerationRequested);
    on<ScanRescanRequested>(_onRescanRequested);
    on<ScanSaveRequested>(_onSaveRequested);
    on<ScanExportRequested>(_onExportRequested);
    on<ScanProgressUpdated>(_onProgressUpdated);
  }

  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(
      status: ScanStatus.scanning,
      coveragePercent: 0.0,
      pointCount: 0,
    ));

    try {
      // Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        emit(state.copyWith(
          status: ScanStatus.error,
          errorMessage: 'No camera found on this device.',
        ));
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      emit(state.copyWith(
        status: ScanStatus.scanning,
        isCameraReady: true,
      ));

      // TODO: Start image stream for real inference
      // _cameraController!.startImageStream((CameraImage frame) {
      //   _inferenceIsolate.processFrame(frame);
      // });

      // STUB: Simulate progress updates for UI testing
      // Remove this block and replace with real inference progress callbacks
      _fakeProgress = 0;
      _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (_fakeProgress < 95) {
          _fakeProgress += math.Random().nextDouble() * 3;
          add(ScanProgressUpdated(
            coveragePercent: _fakeProgress.clamp(0, 100),
            pointCount: (_fakeProgress * 120).toInt(),
          ));
        }
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

  Future<void> _onScanStopped(
    ScanStopped event,
    Emitter<ScanState> emit,
  ) async {
    _progressTimer?.cancel();
    await _cameraController?.stopImageStream().catchError((_) {});
    await _cameraController?.dispose();
    _cameraController = null;
  }

  Future<void> _onMeshGenerationRequested(
    ScanMeshGenerationRequested event,
    Emitter<ScanState> emit,
  ) async {
    _progressTimer?.cancel();
    await _cameraController?.stopImageStream().catchError((_) {});

    emit(state.copyWith(
      status: ScanStatus.processing,
      coveragePercent: 100,
    ));

    try {
      // TODO: Replace with real mesh generation from your PointCloudBuilder
      // final mesh = await _pointCloudBuilder.generateMesh();
      // final baseMap = await _depthEstimator.generateBaseMap();
      // final normalMap = await _depthEstimator.generateNormalMap();

      // STUB: Simulate a 2-second processing delay and return fake mesh stats
      await Future.delayed(const Duration(seconds: 2));

      emit(state.copyWith(status: ScanStatus.meshReady));
    } catch (e) {
      emit(state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Mesh generation failed: $e',
      ));
    }
  }

  void _onProgressUpdated(
    ScanProgressUpdated event,
    Emitter<ScanState> emit,
  ) {
    emit(state.copyWith(
      coveragePercent: event.coveragePercent,
      pointCount: event.pointCount,
    ));
  }

  Future<void> _onRescanRequested(
    ScanRescanRequested event,
    Emitter<ScanState> emit,
  ) async {
    _progressTimer?.cancel();
    await _cameraController?.stopImageStream().catchError((_) {});
    await _cameraController?.dispose();
    _cameraController = null;
    _fakeProgress = 0;
    emit(const ScanState());
  }

  Future<void> _onSaveRequested(
    ScanSaveRequested event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: ScanStatus.saving));
    // TODO: Save to Hive local storage
    // await _hiveRepository.saveScan(SavedScan(...));
    await Future.delayed(const Duration(milliseconds: 500));
    emit(state.copyWith(status: ScanStatus.meshReady));
  }

  Future<void> _onExportRequested(
    ScanExportRequested event,
    Emitter<ScanState> emit,
  ) async {
    emit(state.copyWith(status: ScanStatus.exporting));
    // TODO: Export to OBJ/GLB/STL format
    await Future.delayed(const Duration(milliseconds: 500));
    emit(state.copyWith(status: ScanStatus.meshReady));
  }

  CameraController? get cameraController => _cameraController;

  @override
  Future<void> close() async {
    _progressTimer?.cancel();
    await _cameraController?.stopImageStream().catchError((_) {});
    await _cameraController?.dispose();
    return super.close();
  }
}
