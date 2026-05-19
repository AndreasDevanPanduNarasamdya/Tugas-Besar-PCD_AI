import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/scan_bloc.dart';
import '../../bloc/scan_event.dart';
import '../../bloc/scan_state.dart';
import '../theme/app_theme.dart';
import '../widgets/model_stats_bar.dart';
import 'texture_preview_screen.dart';
import 'model_menu_screen.dart';

/// View mode toggles matching mockup:
/// Row 1: Wireframe | Solid | Material | Render
/// Row 2: Base | Normal | Combined
/// Row 3: ViewPort | Texture
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
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.primaryRed, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Scan Result'),
            actions: [
              // Red icon (matches mockup top-right red circle icon)
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
          body: Column(
            children: [
              // ── Stats bar ──────────────────────────────────────────────
              ModelStatsBar(
                faces: state.mesh?.faceCount ?? 0,
                vertices: state.mesh?.vertexCount ?? 0,
                edges: state.mesh?.edgeCount ?? 0,
                triangles: state.mesh?.triangleCount ?? 0,
              ),

              const SizedBox(height: 4),

              // ── Toggle rows ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    // Row 1: view mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _toggle(
                            'Wireframe',
                            _viewMode == _ViewMode.wireframe,
                            () => setState(
                                () => _viewMode = _ViewMode.wireframe)),
                        const SizedBox(width: 6),
                        _toggle('Solid', _viewMode == _ViewMode.solid,
                            () => setState(() => _viewMode = _ViewMode.solid)),
                        const SizedBox(width: 6),
                        _toggle(
                            'Material',
                            _viewMode == _ViewMode.material,
                            () =>
                                setState(() => _viewMode = _ViewMode.material)),
                        const SizedBox(width: 6),
                        _toggle('Render', _viewMode == _ViewMode.render,
                            () => setState(() => _viewMode = _ViewMode.render)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Row 2: map mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _toggle('Base', _mapMode == _MapMode.base,
                            () => setState(() => _mapMode = _MapMode.base)),
                        const SizedBox(width: 6),
                        _toggle('Normal', _mapMode == _MapMode.normal,
                            () => setState(() => _mapMode = _MapMode.normal)),
                        const SizedBox(width: 6),
                        _toggle('Combined', _mapMode == _MapMode.combined,
                            () => setState(() => _mapMode = _MapMode.combined)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Row 3: display mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _toggle(
                            'ViewPort', _displayMode == _DisplayMode.viewport,
                            () {
                          setState(() => _displayMode = _DisplayMode.viewport);
                        }),
                        const SizedBox(width: 6),
                        _toggle('Texture', _displayMode == _DisplayMode.texture,
                            () {
                          setState(() => _displayMode = _DisplayMode.texture);
                          // Navigate to texture preview
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TexturePreviewScreen()),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── 3D Viewer ──────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  color: const Color(0xFFD0D0D0), // Light grey bg like mockup
                  child: _build3DContent(state),
                ),
              ),

              // ── Bottom buttons ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
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
                        icon: Icon(Icons.refresh,
                            color: AppTheme.textGrey, size: 18),
                        label: Text('Re-Scan',
                            style: TextStyle(color: AppTheme.textGrey)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.textGrey),
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
    if (!state.hasMesh) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryRed));
    }

    // TODO: Replace with real 3D renderer
    // Use model_viewer_plus, flutter_gl, or babylon.js WebView here
    // For now show a placeholder that communicates to the user what's coming
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_in_ar, color: Colors.grey[600], size: 80),
              const SizedBox(height: 12),
              Text(
                '3D Viewer',
                style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Integrate model_viewer_plus or flutter_gl here',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Mode indicator overlay
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _viewMode.name.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, ScanState state) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.bottomNavBg,
        border: const Border(
            top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    builder: (_) => ModelMenuScreen(
                        scanId: 'current', scanName: 'New Scan'),
                  ),
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
                  child: Icon(Icons.crop_free,
                      color: AppTheme.primaryRed, size: 22),
                ),
                Text('Scan Object',
                    style: TextStyle(color: AppTheme.primaryRed, fontSize: 10)),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
          color: active ? AppTheme.primaryRed : Colors.black,
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
