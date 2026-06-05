part of 'scan_bloc.dart';

abstract class ScanEvent {
  const ScanEvent();
}

class ScanStarted extends ScanEvent {
  const ScanStarted();
}

class ScanPhotoCaptured extends ScanEvent {
  const ScanPhotoCaptured();
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

class ScanLoadRequested extends ScanEvent {
  final String scanId;

  const ScanLoadRequested({required this.scanId});

  @override
  List<Object?> get props => [scanId];
}
