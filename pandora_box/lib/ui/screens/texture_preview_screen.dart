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
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.primaryRed, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Scan Result'),
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
          body: Column(
            children: [
              // ── Stats bar ──────────────────────────────────────────────
              ModelStatsBar(
                faces: state.mesh?.faceCount ?? 0,
                vertices: state.mesh?.vertexCount ?? 0,
                edges: state.mesh?.edgeCount ?? 0,
                triangles: state.mesh?.triangleCount ?? 0,
              ),

              const SizedBox(height: 8),

              // ── Base / Normal toggle ───────────────────────────────────
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

              const SizedBox(height: 8),

              // ── Texture display ────────────────────────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildMapContent(state),
                  ),
                ),
              ),

              const SizedBox(height: 8),

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
                          Navigator.popUntil(
                              context, (r) => r.settings.name == '/');
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
                        onPressed: () => context
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
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildMapContent(ScanState state) {
    if (_showBaseMap) {
      if (state.baseMapBytes != null) {
        return Image.memory(state.baseMapBytes!, fit: BoxFit.contain);
      }
      return _buildPlaceholder('Base map not generated yet');
    } else {
      if (state.normalMapBytes != null) {
        return Image.memory(state.normalMapBytes!, fit: BoxFit.contain);
      }
      return _buildPlaceholder('Normal map not generated yet');
    }
  }

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, color: AppTheme.textDarkGrey, size: 52),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            'Complete a scan first to generate maps',
            style: TextStyle(color: AppTheme.textDarkGrey, fontSize: 11),
          ),
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
          color: isActive ? AppTheme.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primaryRed : AppTheme.textGrey,
          ),
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

  Widget _buildBottomNav() {
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
            children: [
              Icon(Icons.home, color: AppTheme.textGrey, size: 24),
              Text('Home',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryRed, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.crop_free, color: AppTheme.primaryRed, size: 22),
              ),
              Text('Scan Object',
                  style: TextStyle(color: AppTheme.primaryRed, fontSize: 10)),
            ],
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
}
