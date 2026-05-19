part of 'scan_bloc.dart';

enum ScanStatus {
  idle,
  scanning,
  processing,
  meshReady,
  saving,
  exporting,
  error
}

class ScanState {
  final ScanStatus status;
  final double coveragePercent;
  final int pointCount;
  final dynamic mesh; // Changed to dynamic to bypass current type conflicts
  final Uint8List? baseMapBytes;
  final Uint8List? normalMapBytes;
  final String? errorMessage;
  final bool isCameraReady;

  const ScanState({
    this.status = ScanStatus.idle,
    this.coveragePercent = 0.0,
    this.pointCount = 0,
    this.mesh,
    this.baseMapBytes,
    this.normalMapBytes,
    this.errorMessage,
    this.isCameraReady = false,
  });

  bool get isScanning => status == ScanStatus.scanning;
  bool get isProcessing => status == ScanStatus.processing;
  bool get hasMesh => status == ScanStatus.meshReady && mesh != null;

  ScanState copyWith({
    ScanStatus? status,
    double? coveragePercent,
    int? pointCount,
    dynamic mesh,
    Uint8List? baseMapBytes,
    Uint8List? normalMapBytes,
    String? errorMessage,
    bool? isCameraReady,
  }) {
    return ScanState(
      status: status ?? this.status,
      coveragePercent: coveragePercent ?? this.coveragePercent,
      pointCount: pointCount ?? this.pointCount,
      mesh: mesh ?? this.mesh,
      baseMapBytes: baseMapBytes ?? this.baseMapBytes,
      normalMapBytes: normalMapBytes ?? this.normalMapBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      isCameraReady: isCameraReady ?? this.isCameraReady,
    );
  }
}
