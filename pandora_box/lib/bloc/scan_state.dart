part of 'scan_bloc.dart';

enum ScanStatus {
  idle,
  scanning,
  processing,
  meshReady,
  saving,
  exporting,
  error,
}

enum ProcessingStep {
  idle,
  aligningPointClouds,
  generatingMesh,
  mappingTextures,
  sharpeningAndEncoding,
  done,
}

extension ProcessingStepX on ProcessingStep {
  String get label {
    switch (this) {
      case ProcessingStep.idle:
        return '';
      case ProcessingStep.aligningPointClouds:
        return 'Aligning angles...';
      case ProcessingStep.generatingMesh:
        return 'Generating mesh...';
      case ProcessingStep.mappingTextures:
        return 'Mapping textures...';
      case ProcessingStep.sharpeningAndEncoding:
        return 'Finalizing maps...';
      case ProcessingStep.done:
        return 'Done!';
    }
  }
}

class ScanState {
  final ScanStatus status;
  final int capturedCount; // 0–4
  final bool isCapturingFrame;
  final int pointCount; // live point cloud size shown in UI
  final double processingProgress;
  final ProcessingStep processingStep;
  final MeshData? mesh;
  final Uint8List? baseMapBytes;
  final Uint8List? normalMapBytes;
  final String? exportPath;
  final String? errorMessage;
  final bool isCameraReady;

  const ScanState({
    this.status = ScanStatus.idle,
    this.capturedCount = 0,
    this.isCapturingFrame = false,
    this.pointCount = 0,
    this.processingProgress = 0.0,
    this.processingStep = ProcessingStep.idle,
    this.mesh,
    this.baseMapBytes,
    this.normalMapBytes,
    this.exportPath,
    this.errorMessage,
    this.isCameraReady = false,
  });

  bool get isScanning => status == ScanStatus.scanning;
  bool get isProcessing => status == ScanStatus.processing;
  bool get hasMesh => mesh != null && status == ScanStatus.meshReady;
  bool get hasError => status == ScanStatus.error;

  ScanState copyWith({
    ScanStatus? status,
    int? capturedCount,
    bool? isCapturingFrame,
    int? pointCount,
    double? processingProgress,
    ProcessingStep? processingStep,
    MeshData? mesh,
    Uint8List? baseMapBytes,
    Uint8List? normalMapBytes,
    String? exportPath,
    String? errorMessage,
    bool? isCameraReady,
  }) {
    return ScanState(
      status: status ?? this.status,
      capturedCount: capturedCount ?? this.capturedCount,
      isCapturingFrame: isCapturingFrame ?? this.isCapturingFrame,
      pointCount: pointCount ?? this.pointCount,
      processingProgress: processingProgress ?? this.processingProgress,
      processingStep: processingStep ?? this.processingStep,
      mesh: mesh ?? this.mesh,
      baseMapBytes: baseMapBytes ?? this.baseMapBytes,
      normalMapBytes: normalMapBytes ?? this.normalMapBytes,
      exportPath: exportPath ?? this.exportPath,
      errorMessage: errorMessage ?? this.errorMessage,
      isCameraReady: isCameraReady ?? this.isCameraReady,
    );
  }
}
