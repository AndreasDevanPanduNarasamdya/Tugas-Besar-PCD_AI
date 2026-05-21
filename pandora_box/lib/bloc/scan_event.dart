part of 'scan_bloc.dart';

abstract class ScanEvent {
  const ScanEvent();
}

class ScanStarted extends ScanEvent {
  const ScanStarted();
}

class ScanStopped extends ScanEvent {
  const ScanStopped();
}

class ScanFrameReceived extends ScanEvent {
  final CameraImage cameraImage;
  const ScanFrameReceived({required this.cameraImage});
}

class ScanMeshGenerationRequested extends ScanEvent {
  const ScanMeshGenerationRequested();
}

class ScanRescanRequested extends ScanEvent {
  const ScanRescanRequested();
}

class ScanSaveRequested extends ScanEvent {
  final String name;
  const ScanSaveRequested({required this.name});
}

class ScanExportRequested extends ScanEvent {
  final String scanId;
  const ScanExportRequested({required this.scanId});
}

class ScanProgressUpdated extends ScanEvent {
  final double coveragePercent;
  final int pointCount;
  const ScanProgressUpdated({
    required this.coveragePercent,
    required this.pointCount,
  });
}
