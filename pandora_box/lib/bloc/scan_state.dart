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

class ScanState {
  final ScanStatus status;
  final double coveragePercent;
  final int pointCount;
  final int frameCount;
  final double processingProgress;
  final MeshData? mesh;
  final Uint8List? baseMapBytes;
  final Uint8List? normalMapBytes;
  final String? exportPath;
  final String? errorMessage;
  final bool isCameraReady;

  const ScanState({
    this.status = ScanStatus.idle,
    this.coveragePercent = 0.0,
    this.pointCount = 0,
    this.frameCount = 0,
    this.processingProgress = 0.0,
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
  bool get hasError => errorMessage != null && status == ScanStatus.error;

  ScanState copyWith({
    ScanStatus? status,
    double? coveragePercent,
    int? pointCount,
    int? frameCount,
    double? processingProgress,
    MeshData? mesh,
    Uint8List? baseMapBytes,
    Uint8List? normalMapBytes,
    String? exportPath,
    String? errorMessage,
    bool? isCameraReady,
  }) {
    return ScanState(
      status: status ?? this.status,
      coveragePercent: coveragePercent ?? this.coveragePercent,
      pointCount: pointCount ?? this.pointCount,
      frameCount: frameCount ?? this.frameCount,
      processingProgress: processingProgress ?? this.processingProgress,
      mesh: mesh ?? this.mesh,
      baseMapBytes: baseMapBytes ?? this.baseMapBytes,
      normalMapBytes: normalMapBytes ?? this.normalMapBytes,
      exportPath: exportPath ?? this.exportPath,
      errorMessage: errorMessage ?? this.errorMessage,
      isCameraReady: isCameraReady ?? this.isCameraReady,
    );
  }
}
