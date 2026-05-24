import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/scan_bloc.dart';
import '../theme/app_theme.dart';

class ModelMenuScreen extends StatelessWidget {
  final String scanId;
  final String scanName;

  const ModelMenuScreen({
    super.key,
    required this.scanId,
    required this.scanName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        // Calculate real size, fallback to 0 if null
        final sizeMb = ((state.baseMapBytes?.length ?? 0) / (1024 * 1024));
        final sizeLabel =
            sizeMb > 0 ? '${sizeMb.toStringAsFixed(1)} MB' : '0 MB';

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.primaryRed, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: const SizedBox.shrink(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryRed, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.view_in_ar,
                      color: AppTheme.primaryRed, size: 20),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Large thumbnail ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: state.baseMapBytes != null
                        ? Image.memory(state.baseMapBytes!, fit: BoxFit.cover)
                        : const Center(
                            child: Icon(Icons.image_not_supported,
                                color: AppTheme.textDarkGrey, size: 72)),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Name + size row ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      scanName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                    Text(
                      sizeLabel,
                      style: const TextStyle(
                          color: AppTheme.textGrey, fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Real Stats rows ────────────────────────────────────────────
                _buildStatRow(Icons.square_outlined, 'Faces',
                    '${state.mesh?.faceCount ?? 0}'),
                _buildStatRow(
                    Icons.timeline, 'Edges', '${state.mesh?.edgeCount ?? 0}'),
                _buildStatRow(Icons.adjust, 'Vertices',
                    '${state.mesh?.vertexCount ?? 0}'),
                _buildStatRow(Icons.change_history, 'Triangles',
                    '${state.mesh?.triangleCount ?? 0}'),

                const Spacer(),

                // ── Action buttons ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context), // Goes back to 3D Viewer
                    icon: const Icon(Icons.desktop_windows_outlined, size: 18),
                    label: const Text('3D Viewer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context
                        .read<ScanBloc>()
                        .add(ScanExportRequested(scanId: scanId)),
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Export to'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<ScanBloc>().add(const ScanRescanRequested());
                      Navigator.popUntil(
                          context, (r) => r.settings.name == '/');
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Re-scan Object'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(context),
        );
      },
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textGrey, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppTheme.bottomNavBg,
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.home, color: AppTheme.textGrey, size: 24),
                Text('Home',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
              ],
            ),
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
                child: const Icon(Icons.crop_free,
                    color: AppTheme.primaryRed, size: 22),
              ),
              const Text('Scan Object',
                  style: TextStyle(color: AppTheme.primaryRed, fontSize: 10)),
            ],
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
}
