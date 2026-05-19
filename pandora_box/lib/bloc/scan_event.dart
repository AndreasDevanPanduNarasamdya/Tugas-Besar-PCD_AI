part of 'scan_bloc.dart';

abstract class ScanEvent {
  const ScanEvent();
}

/// Fired when ScanScreen is opened - starts camera
class ScanStarted extends ScanEvent {
  const ScanStarted();
}

/// Fired when ScanScreen is closed - releases camera
class ScanStopped extends ScanEvent {
  const ScanStopped();
}

/// User pressed the stop/render button - triggers mesh generation
class ScanMeshGenerationRequested extends ScanEvent {
  const ScanMeshGenerationRequested();
}

/// User hit Re-scan - resets everything
class ScanRescanRequested extends ScanEvent {
  const ScanRescanRequested();
}

/// Save the scan with a name
class ScanSaveRequested extends ScanEvent {
  final String name;
  const ScanSaveRequested({required this.name});
}

/// Export the scan
class ScanExportRequested extends ScanEvent {
  final String scanId;
  const ScanExportRequested({required this.scanId});
}

/// A new camera frame arrived (triggers frame processing)
class ScanFrameReceived extends ScanEvent {
  const ScanFrameReceived();
}

/// Coverage/progress update from isolate
class ScanProgressUpdated extends ScanEvent {
  final double coveragePercent;
  final int pointCount;
  const ScanProgressUpdated({
    required this.coveragePercent,
    required this.pointCount,
  });
}
