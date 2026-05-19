import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:pandora_box/storage/scan_model.dart';

/// Handles all local persistence for scans using Hive.
///
/// Usage:
///   final repo = ScanRepository();
///   await repo.init();                  // call once in main()
///   final id = await repo.saveScan(...);
///   final all = repo.getAllScans();
class ScanRepository {
  static const String _boxName = 'scans';
  late Box<ScanModel> _box;
  bool _initialized = false;

  /// Must be called before any other method.
  /// Registers the Hive adapter and opens the box.
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    // Only register if not already registered (safe for hot reload)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ScanModelAdapter());
    }

    _box = await Hive.openBox<ScanModel>(_boxName);
    _initialized = true;
    print('[ScanRepository] Initialized with ${_box.length} scans');
  }

  void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
          'ScanRepository.init() must be called before using the repository.');
    }
  }

  /// Saves a completed scan to local storage and returns its generated ID.
  Future<String> saveScan({
    required String name,
    required Uint8List thumbnail,
    required Uint8List baseMap,
    required Uint8List normalMap,
    required Uint8List pointCloud,
    required int frameCount,
    required int faceCount,
    required int vertexCount,
    required int edgeCount,
    required int triangleCount,
    String exportPath = '',
  }) async {
    _assertInitialized();

    final id = const Uuid().v4();
    final fileSizeMb =
        (baseMap.length + normalMap.length + pointCloud.length) / (1024 * 1024);

    final scan = ScanModel()
      ..modelId = id
      ..modelName = name
      ..timestamp = DateTime.now()
      ..thumbnail = thumbnail
      ..baseMap = baseMap
      ..normalMap = normalMap
      ..pointCloud = pointCloud
      ..exportPath = exportPath
      ..frameCount = frameCount
      ..isMeshGenerated = true
      ..faceCount = faceCount
      ..vertexCount = vertexCount
      ..edgeCount = edgeCount
      ..triangleCount = triangleCount
      ..fileSizeMb = fileSizeMb;

    await _box.put(id, scan);
    print('[ScanRepository] Saved scan: $name ($id) — '
        '${fileSizeMb.toStringAsFixed(1)} MB');
    return id;
  }

  /// Returns all scans sorted newest-first.
  List<ScanModel> getAllScans() {
    _assertInitialized();
    return _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Returns a single scan by ID, or null if not found.
  ScanModel? getScan(String id) {
    _assertInitialized();
    return _box.get(id);
  }

  /// Permanently deletes a scan.
  Future<void> deleteScan(String id) async {
    _assertInitialized();
    await _box.delete(id);
    print('[ScanRepository] Deleted scan: $id');
  }

  /// Updates the export path after a scan has been exported to OBJ/GLB/STL.
  Future<void> updateExportPath(String id, String path) async {
    _assertInitialized();
    final scan = _box.get(id);
    if (scan != null) {
      scan.exportPath = path;
      await scan.save();
      print('[ScanRepository] Export path updated for $id → $path');
    }
  }

  /// Returns true if any scans exist in storage.
  bool get isEmpty => _box.isEmpty;

  /// Total number of saved scans.
  int get count => _box.length;

  Future<void> close() async {
    await _box.close();
    _initialized = false;
  }
}
