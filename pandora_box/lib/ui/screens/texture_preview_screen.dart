import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/scan_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/model_stats_bar.dart';

class TexturePreviewScreen extends StatefulWidget {
  const TexturePreviewScreen({super.key});

  @override
  State<TexturePreviewScreen> createState() => _TexturePreviewScreenState();
}

class _TexturePreviewScreenState extends State<TexturePreviewScreen> {
  bool _showBaseMap = true;

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
                      color: AppTheme.primaryRed, shape: BoxShape.circle),
                  child: const Icon(Icons.view_in_ar,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Full Screen Texture ───────────────────────────
              Container(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: _buildMapContent(state),
                ),
              ),

              // ── Layer 2: Floating UI Controls ────────────────────────────
              SafeArea(
                child: Column(
                  children: [
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildToggle('Base', _showBaseMap,
                            () => setState(() => _showBaseMap = true)),
                        const SizedBox(width: 8),
                        _buildToggle('Normal', !_showBaseMap,
                            () => setState(() => _showBaseMap = false)),
                      ],
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
                          Navigator.popUntil(context, (r) => r.isFirst);
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
                        icon: const Icon(Icons.download, size: 18),
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
        );
      },
    );
  }

  Widget _buildMapContent(ScanState state) {
    if (_showBaseMap && state.baseMapBytes != null) {
      return Image.memory(state.baseMapBytes!, fit: BoxFit.contain);
    } else if (!_showBaseMap && state.normalMapBytes != null) {
      return Image.memory(state.normalMapBytes!, fit: BoxFit.contain);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined,
              color: AppTheme.textDarkGrey.withOpacity(0.5), size: 52),
          const SizedBox(height: 12),
          const Text('Texture not generated yet',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryRed : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? AppTheme.primaryRed : AppTheme.textGrey),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textGrey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
