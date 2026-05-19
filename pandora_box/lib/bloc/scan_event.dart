import 'package:equatable/equatable.dart';
import 'dart:typed_data';

abstract class ScanEvent extends Equatable {
  const ScanEvent();
  @override
  List<Object?> get props => [];
}

class ScanStarted extends ScanEvent {
  const ScanStarted();
}

class ScanFrameReceived extends ScanEvent {
  final Uint8List rgbFrame;
  final int width;
  final int height;

  const ScanFrameReceived({
    required this.rgbFrame,
    required this.width,
    required this.height,
  });

  @override
  List<Object?> get props => [rgbFrame, width, height];
}

class ScanStopped extends ScanEvent {
  const ScanStopped();
}

class ScanMeshGenerationRequested extends ScanEvent {
  const ScanMeshGenerationRequested();
}

class ScanSaveRequested extends ScanEvent {
  final String name;
  const ScanSaveRequested({required this.name});

  @override
  List<Object?> get props => [name];
}

class ScanExportRequested extends ScanEvent {
  final String scanId;
  const ScanExportRequested({required this.scanId});

  @override
  List<Object?> get props => [scanId];
}

class ScanRescanRequested extends ScanEvent {
  const ScanRescanRequested();
}

class ScanDeleted extends ScanEvent {
  final String scanId;
  const ScanDeleted({required this.scanId});

  @override
  List<Object?> get props => [scanId];
}
