import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/scan_bloc.dart';
import '../../reconstruction/mesh_generator.dart';
import '../theme/app_theme.dart';
import '../widgets/model_stats_bar.dart';
import 'texture_preview_screen.dart';
import 'model_menu_screen.dart';
import 'dart:ui' as import_ui;

enum _ViewMode { wireframe, solid, material, render }

enum _MapMode { base, normal, combined }

enum _DisplayMode { viewport, texture }

class Preview3DScreen extends StatefulWidget {
  const Preview3DScreen({Key? key}) : super(key: key);

  @override
  State<Preview3DScreen> createState() => _Preview3DScreenState();
}

class _Preview3DScreenState extends State<Preview3DScreen> {
  _ViewMode _viewMode = _ViewMode.render;
  _MapMode _mapMode = _MapMode.base;
  _DisplayMode _displayMode = _DisplayMode.viewport;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          extendBodyBehindAppBar: true, // Let 3D model go behind app bar
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.primaryRed, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Scan Result',
                style: TextStyle(
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.view_in_ar,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Full Screen 3D Viewer ───────────────────────────
              Container(
                color: const Color(0xFFD0D0D0), // Light grey bg like mockup
                child: _build3DContent(state),
              ),

              // ── Layer 2: Floating UI Controls ────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    // Stats Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.primaryRed.withOpacity(0.5)),
                        ),
                        child: ModelStatsBar(
                          faces: state.mesh?.faceCount ?? 0,
                          vertices: state.mesh?.vertexCount ?? 0,
                          edges: state.mesh?.edgeCount ?? 0,
                          triangles: state.mesh?.triangleCount ?? 0,
                        ),
                      ),
                    ),

                    // Toggles
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _toggle(
                                    'Wireframe',
                                    _viewMode == _ViewMode.wireframe,
                                    () => setState(
                                        () => _viewMode = _ViewMode.wireframe)),
                                const SizedBox(width: 6),
                                _toggle(
                                    'Solid',
                                    _viewMode == _ViewMode.solid,
                                    () => setState(
                                        () => _viewMode = _ViewMode.solid)),
                                const SizedBox(width: 6),
                                _toggle(
                                    'Material',
                                    _viewMode == _ViewMode.material,
                                    () => setState(
                                        () => _viewMode = _ViewMode.material)),
                                const SizedBox(width: 6),
                                _toggle(
                                    'Render',
                                    _viewMode == _ViewMode.render,
                                    () => setState(
                                        () => _viewMode = _ViewMode.render)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _toggle(
                                    'Base',
                                    _mapMode == _MapMode.base,
                                    () => setState(
                                        () => _mapMode = _MapMode.base)),
                                const SizedBox(width: 6),
                                _toggle(
                                    'Normal',
                                    _mapMode == _MapMode.normal,
                                    () => setState(
                                        () => _mapMode = _MapMode.normal)),
                                const SizedBox(width: 6),
                                _toggle(
                                    'Combined',
                                    _mapMode == _MapMode.combined,
                                    () => setState(
                                        () => _mapMode = _MapMode.combined)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _toggle(
                                    'ViewPort',
                                    _displayMode == _DisplayMode.viewport,
                                    () => setState(() =>
                                        _displayMode = _DisplayMode.viewport)),
                                const SizedBox(width: 6),
                                _toggle('Texture',
                                    _displayMode == _DisplayMode.texture, () {
                                  setState(() =>
                                      _displayMode = _DisplayMode.texture);
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const TexturePreviewScreen()));
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Layer 3: Bottom Action Buttons ───────────────────────────
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context
                              .read<ScanBloc>()
                              .add(const ScanRescanRequested());
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.refresh,
                            color: Colors.white, size: 18),
                        label: const Text('Re-Scan',
                            style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.status == ScanStatus.saving
                            ? null
                            : () => context
                                .read<ScanBloc>()
                                .add(const ScanSaveRequested(name: 'New Scan')),
                        icon: state.status == ScanStatus.saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download, size: 18),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(context, state),
        );
      },
    );
  }

  Widget _build3DContent(ScanState state) {
    if (state.isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryRed),
            const SizedBox(height: 16),
            Text(
              'Generating mesh... ${(state.processingProgress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (!state.hasMesh || state.mesh == null || state.mesh!.vertexCount == 0) {
      return const Center(
        child: Text('Waiting for mesh generation...',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return _NativePointCloudViewer(
      mesh: state.mesh!,
      viewMode: _viewMode,
      mapMode: _mapMode,
      baseMapBytes: state.baseMapBytes,
      normalMapBytes: state.normalMapBytes,
    );
  }

  Widget _buildBottomNav(BuildContext context, ScanState state) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppTheme.bottomNavBg,
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.home, color: AppTheme.textGrey, size: 24),
              Text('Home',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
            ],
          ),
          GestureDetector(
            onTap: () {
              if (state.hasMesh) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ModelMenuScreen(
                          scanId: 'current', scanName: 'New Scan')),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryRed, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.crop_free,
                      color: AppTheme.primaryRed, size: 22),
                ),
                const Text('Scan Object',
                    style: TextStyle(color: AppTheme.primaryRed, fontSize: 10)),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.settings, color: AppTheme.textGrey, size: 24),
              Text('Settings',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryRed : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active ? AppTheme.primaryRed : const Color(0xFF333333),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.textGrey,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Native 3D Point Cloud Renderer ──────────────────────────────────────────

class _NativePointCloudViewer extends StatefulWidget {
  final MeshData mesh;
  final _ViewMode viewMode;
  final _MapMode mapMode;
  final Uint8List? baseMapBytes;
  final Uint8List? normalMapBytes;

  const _NativePointCloudViewer({
    Key? key,
    required this.mesh,
    required this.viewMode,
    required this.mapMode,
    this.baseMapBytes,
    this.normalMapBytes,
  }) : super(key: key);

  @override
  State<_NativePointCloudViewer> createState() =>
      _NativePointCloudViewerState();
}

class _NativePointCloudViewerState extends State<_NativePointCloudViewer> {
  double _pitch = 0.2;
  double _yaw = 0.3;
  double _zoom = 1.0;
  double _baseZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _baseZoom = _zoom;
      },
      onScaleUpdate: (details) {
        setState(() {
          // Scale handles both pinch zoom AND single finger pan
          if (details.pointerCount == 1) {
            // Single finger — rotate
            _yaw -= details.focalPointDelta.dx * 0.01;
            _pitch += details.focalPointDelta.dy * 0.01;
            _pitch = _pitch.clamp(-math.pi / 2, math.pi / 2);
          } else {
            // Two fingers — zoom
            _zoom = (_baseZoom * details.scale).clamp(0.1, 10.0);
          }
        });
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _MeshPainter(
          mesh: widget.mesh,
          viewMode: widget.viewMode,
          pitch: _pitch,
          yaw: _yaw,
          zoom: _zoom,
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final MeshData mesh;
  final _ViewMode viewMode;
  final double pitch, yaw, zoom;

  _MeshPainter({
    required this.mesh,
    required this.viewMode,
    required this.pitch,
    required this.yaw,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final cosY = math.cos(yaw), sinY = math.sin(yaw);

    // Project all vertices to 2D
    final projected = <Offset>[];
    final depths = <double>[];
    final vertCount = mesh.vertices.length ~/ 3;

    for (int i = 0; i < vertCount; i++) {
      final x = mesh.vertices[i * 3];
      final y = mesh.vertices[i * 3 + 1];
      final z = mesh.vertices[i * 3 + 2];

      // Rotate Y axis
      final x1 = x * cosY - z * sinY;
      final z1 = x * sinY + z * cosY;
      // Rotate X axis
      final y2 = y * cosP - z1 * sinP;
      final z2 = y * sinP + z1 * cosP;

      projected.add(Offset(cx + x1 * 300 * zoom, cy + y2 * 300 * zoom));
      depths.add(z2);
    }

    switch (viewMode) {
      case _ViewMode.wireframe:
        _drawWireframe(canvas, projected, depths);
        break;
      case _ViewMode.solid:
        _drawSolid(canvas, projected, depths);
        break;
      case _ViewMode.material:
      case _ViewMode.render:
        _drawColored(canvas, projected, depths);
        break;
    }
  }

  void _drawWireframe(
      Canvas canvas, List<Offset> projected, List<double> depths) {
    final paint = Paint()
      ..color = AppTheme.primaryRed.withOpacity(0.7)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Sort faces by average depth
    final faces = <_Face>[];
    for (int i = 0; i < mesh.indices.length; i += 3) {
      final a = mesh.indices[i];
      final b = mesh.indices[i + 1];
      final c = mesh.indices[i + 2];
      if (a >= projected.length ||
          b >= projected.length ||
          c >= projected.length) continue;
      final avgZ = (depths[a] + depths[b] + depths[c]) / 3;
      faces.add(_Face(a, b, c, avgZ));
    }
    faces.sort((x, y) => y.avgZ.compareTo(x.avgZ));

    for (final f in faces) {
      final path = Path()
        ..moveTo(projected[f.a].dx, projected[f.a].dy)
        ..lineTo(projected[f.b].dx, projected[f.b].dy)
        ..lineTo(projected[f.c].dx, projected[f.c].dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawSolid(Canvas canvas, List<Offset> projected, List<double> depths) {
    final faces = <_Face>[];
    for (int i = 0; i < mesh.indices.length; i += 3) {
      final a = mesh.indices[i];
      final b = mesh.indices[i + 1];
      final c = mesh.indices[i + 2];
      if (a >= projected.length ||
          b >= projected.length ||
          c >= projected.length) continue;
      final avgZ = (depths[a] + depths[b] + depths[c]) / 3;
      faces.add(_Face(a, b, c, avgZ));
    }
    faces.sort((x, y) => y.avgZ.compareTo(x.avgZ));

    final fillPaint = Paint()
      ..color = const Color(0xFF888888)
      ..style = PaintingStyle.fill;
    final wirePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 0.3
      ..style = PaintingStyle.stroke;

    for (final f in faces) {
      // Simple lambertian shading from normal
      double shade = 0.7;
      if (f.a * 3 + 2 < mesh.normals.length) {
        final nx = mesh.normals[f.a * 3];
        final ny = mesh.normals[f.a * 3 + 1];
        final nz = mesh.normals[f.a * 3 + 2];
        // Light from top-right-front
        shade = (nx * 0.3 + ny * 0.5 + nz * 0.2).clamp(0.2, 1.0);
      }
      final grey = (shade * 200).toInt().clamp(0, 255);

      final path = Path()
        ..moveTo(projected[f.a].dx, projected[f.a].dy)
        ..lineTo(projected[f.b].dx, projected[f.b].dy)
        ..lineTo(projected[f.c].dx, projected[f.c].dy)
        ..close();

      fillPaint.color = Color.fromARGB(255, grey, grey, grey);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, wirePaint);
    }
  }

  void _drawColored(
      Canvas canvas, List<Offset> projected, List<double> depths) {
    if (mesh.indices.isEmpty) {
      // Fallback — draw point cloud
      final paint = Paint()
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final points = <_ProjectedPoint>[];
      for (int i = 0; i < projected.length; i++) {
        points.add(_ProjectedPoint(
          x: projected[i].dx,
          y: projected[i].dy,
          z: depths[i],
          r: (mesh.colors[i * 3] * 255).toInt().clamp(0, 255),
          g: (mesh.colors[i * 3 + 1] * 255).toInt().clamp(0, 255),
          b: (mesh.colors[i * 3 + 2] * 255).toInt().clamp(0, 255),
        ));
      }
      points.sort((a, b) => b.z.compareTo(a.z));
      for (final pt in points) {
        paint.color = Color.fromARGB(255, pt.r, pt.g, pt.b);
        canvas.drawPoints(
            import_ui.PointMode.points, [Offset(pt.x, pt.y)], paint);
      }
      return;
    }

    // Draw colored triangles
    final faces = <_Face>[];
    for (int i = 0; i < mesh.indices.length; i += 3) {
      final a = mesh.indices[i];
      final b = mesh.indices[i + 1];
      final c = mesh.indices[i + 2];
      if (a >= projected.length ||
          b >= projected.length ||
          c >= projected.length) continue;
      final avgZ = (depths[a] + depths[b] + depths[c]) / 3;
      faces.add(_Face(a, b, c, avgZ));
    }
    faces.sort((x, y) => y.avgZ.compareTo(x.avgZ));

    final paint = Paint()..style = PaintingStyle.fill;

    for (final f in faces) {
      // Average vertex colors
      final r = ((mesh.colors[f.a * 3] +
                  mesh.colors[f.b * 3] +
                  mesh.colors[f.c * 3]) /
              3 *
              255)
          .toInt()
          .clamp(0, 255);
      final g = ((mesh.colors[f.a * 3 + 1] +
                  mesh.colors[f.b * 3 + 1] +
                  mesh.colors[f.c * 3 + 1]) /
              3 *
              255)
          .toInt()
          .clamp(0, 255);
      final b = ((mesh.colors[f.a * 3 + 2] +
                  mesh.colors[f.b * 3 + 2] +
                  mesh.colors[f.c * 3 + 2]) /
              3 *
              255)
          .toInt()
          .clamp(0, 255);

      // Lambertian shading
      double shade = 0.8;
      if (f.a * 3 + 2 < mesh.normals.length) {
        final nx = mesh.normals[f.a * 3];
        final ny = mesh.normals[f.a * 3 + 1];
        final nz = mesh.normals[f.a * 3 + 2];
        shade = (nx * 0.3 + ny * 0.5 + nz * 0.3 + 0.4).clamp(0.3, 1.0);
      }

      paint.color = Color.fromARGB(
        255,
        (r * shade).toInt().clamp(0, 255),
        (g * shade).toInt().clamp(0, 255),
        (b * shade).toInt().clamp(0, 255),
      );

      final path = Path()
        ..moveTo(projected[f.a].dx, projected[f.a].dy)
        ..lineTo(projected[f.b].dx, projected[f.b].dy)
        ..lineTo(projected[f.c].dx, projected[f.c].dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) =>
      old.pitch != pitch ||
      old.yaw != yaw ||
      old.zoom != zoom ||
      old.viewMode != viewMode;
}

class _Face {
  final int a, b, c;
  final double avgZ;
  _Face(this.a, this.b, this.c, this.avgZ);
}

class _ProjectedPoint {
  final double x, y, z;
  final int r, g, b;
  _ProjectedPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.r,
    required this.g,
    required this.b,
  });
}
