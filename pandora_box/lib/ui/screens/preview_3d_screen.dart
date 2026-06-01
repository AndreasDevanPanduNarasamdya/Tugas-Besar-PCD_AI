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
  _ViewMode _viewMode = _ViewMode.material;
  _MapMode _mapMode = _MapMode.base;
  _DisplayMode _displayMode = _DisplayMode.viewport;

  // Which rows are expanded
  bool _row0Expanded = true;
  bool _row1Expanded = true;
  bool _row2Expanded = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle:
                true, // <--- Forces true center between leading and actions
            leading: IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.primaryRed, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Scan Result',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
            actions: [
              // Stats box top-right
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2), // Reduced padding
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryRed, width: 1.2),
                  ),
                  // FittedBox forces the content to shrink instead of overflowing
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statRow(
                            Icons.change_history,
                            '${state.mesh?.faceCount ?? 0} Faces',
                            '${state.mesh?.vertexCount ?? 0} Vertices'),
                        const SizedBox(height: 2),
                        _statRow(
                            Icons.change_history,
                            '${state.mesh?.edgeCount ?? 0} Edges',
                            '${state.mesh?.triangleCount ?? 0} Triangles'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Full screen 3D viewport ─────────────────────────────────
              _build3DContent(state),

              // ── Left toggle column + expandable rows ────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 56, left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      _ToggleRow(
                        icon: Icons.view_in_ar,
                        expanded: _row0Expanded,
                        onIconTap: () =>
                            setState(() => _row0Expanded = !_row0Expanded),
                        children: [
                          _pill(
                              'Wireframe',
                              _viewMode == _ViewMode.wireframe,
                              () => setState(
                                  () => _viewMode = _ViewMode.wireframe)),
                          _pill(
                              'Solid',
                              _viewMode == _ViewMode.solid,
                              () =>
                                  setState(() => _viewMode = _ViewMode.solid)),
                          _pill(
                              'Material',
                              _viewMode == _ViewMode.material,
                              () => setState(
                                  () => _viewMode = _ViewMode.material)),
                          _pill(
                              'Render',
                              _viewMode == _ViewMode.render,
                              () =>
                                  setState(() => _viewMode = _ViewMode.render)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ToggleRow(
                        icon: Icons.grid_4x4,
                        expanded: _row1Expanded,
                        onIconTap: () =>
                            setState(() => _row1Expanded = !_row1Expanded),
                        children: [
                          _pill('Base', _mapMode == _MapMode.base,
                              () => setState(() => _mapMode = _MapMode.base)),
                          _pill('Normal', _mapMode == _MapMode.normal,
                              () => setState(() => _mapMode = _MapMode.normal)),
                          _pill(
                              'Combined',
                              _mapMode == _MapMode.combined,
                              () =>
                                  setState(() => _mapMode = _MapMode.combined)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ToggleRow(
                        icon: Icons.remove_red_eye_outlined,
                        expanded: _row2Expanded,
                        onIconTap: () =>
                            setState(() => _row2Expanded = !_row2Expanded),
                        children: [
                          _pill(
                              'ViewPort',
                              _displayMode == _DisplayMode.viewport,
                              () => setState(
                                  () => _displayMode = _DisplayMode.viewport)),
                          _pill('Texture', _displayMode == _DisplayMode.texture,
                              () {
                            setState(() => _displayMode = _DisplayMode.texture);
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

              // ── Bottom buttons ──────────────────────────────────────────
              Positioned(
                bottom: 24,
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
                        icon: const Icon(Icons.crop_free,
                            color: Colors.white, size: 18),
                        label: const Text('Re-Scan',
                            style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.65),
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
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
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statRow(IconData icon, String left, String right) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primaryRed, size: 11),
        const SizedBox(width: 3),
        Text(left, style: const TextStyle(color: Colors.white, fontSize: 10)),
        const SizedBox(width: 8),
        Icon(icon, color: AppTheme.primaryRed, size: 11),
        const SizedBox(width: 3),
        Text(right, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryRed : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppTheme.primaryRed : const Color(0xFF444444),
            width: 1,
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
      return Container(
        color: const Color(0xFFCCCCCC),
        child: const Center(
          child: Text('Waiting for mesh generation...',
              style: TextStyle(color: Colors.grey)),
        ),
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
}

// ── Animated toggle row ──────────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final bool expanded;
  final VoidCallback onIconTap;
  final List<Widget> children;

  const _ToggleRow({
    required this.icon,
    required this.expanded,
    required this.onIconTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left icon toggle button
        GestureDetector(
          onTap: onIconTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: expanded
                  ? AppTheme.primaryRed
                  : Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: expanded ? AppTheme.primaryRed : const Color(0xFF444444),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),

        // Animated expanding pill buttons
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: expanded
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      ...children
                          .expand((w) => [w, const SizedBox(width: 5)])
                          .toList()
                        ..removeLast(),
                    ],
                  )
                : const SizedBox(width: 0, height: 36),
          ),
        ),
      ],
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
      onScaleStart: (_) => _baseZoom = _zoom,
      onScaleUpdate: (details) {
        setState(() {
          if (details.pointerCount == 1) {
            _yaw -= details.focalPointDelta.dx * 0.01;
            _pitch += details.focalPointDelta.dy * 0.01;
            _pitch = _pitch.clamp(-math.pi / 2, math.pi / 2);
          } else {
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

    final projected = <Offset>[];
    final depths = <double>[];
    final vertCount = mesh.vertices.length ~/ 3;

    for (int i = 0; i < vertCount; i++) {
      final x = mesh.vertices[i * 3];
      final y = mesh.vertices[i * 3 + 1];
      final z = mesh.vertices[i * 3 + 2];
      final x1 = x * cosY - z * sinY;
      final z1 = x * sinY + z * cosY;
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

    final faces = _sortedFaces(projected, depths);
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
    final faces = _sortedFaces(projected, depths);
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final wirePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 0.3
      ..style = PaintingStyle.stroke;

    for (final f in faces) {
      double shade = 0.7;
      if (f.a * 3 + 2 < mesh.normals.length) {
        final nx = mesh.normals[f.a * 3];
        final ny = mesh.normals[f.a * 3 + 1];
        final nz = mesh.normals[f.a * 3 + 2];
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

    final faces = _sortedFaces(projected, depths);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final f in faces) {
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

  List<_Face> _sortedFaces(List<Offset> projected, List<double> depths) {
    final faces = <_Face>[];
    for (int i = 0; i < mesh.indices.length; i += 3) {
      final a = mesh.indices[i];
      final b = mesh.indices[i + 1];
      final c = mesh.indices[i + 2];
      if (a >= projected.length ||
          b >= projected.length ||
          c >= projected.length) continue;
      faces.add(_Face(a, b, c, (depths[a] + depths[b] + depths[c]) / 3));
    }
    faces.sort((x, y) => y.avgZ.compareTo(x.avgZ));
    return faces;
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
  _ProjectedPoint(
      {required this.x,
      required this.y,
      required this.z,
      required this.r,
      required this.g,
      required this.b});
}
