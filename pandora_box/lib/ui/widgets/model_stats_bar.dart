import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The top stats bar showing Faces / Vertices / Edges / Triangles
/// Matches mockup: compact, red border, icons + numbers
class ModelStatsBar extends StatelessWidget {
  final int faces;
  final int vertices;
  final int edges;
  final int triangles;
  final bool compact; // true = smaller version for preview screens

  const ModelStatsBar({
    Key? key,
    required this.faces,
    required this.vertices,
    required this.edges,
    required this.triangles,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      padding: EdgeInsets.symmetric(
        vertical: compact ? 6 : 8,
        horizontal: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border.all(color: AppTheme.primaryRed.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(Icons.square_outlined, 'Faces', faces, compact),
          _divider(),
          _buildStat(Icons.adjust, 'Vertices', vertices, compact),
          _divider(),
          _buildStat(Icons.timeline, 'Edges', edges, compact),
          _divider(),
          _buildStat(Icons.change_history, 'Triangles', triangles, compact),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: AppTheme.cardBorder,
    );
  }

  Widget _buildStat(IconData icon, String label, int value, bool compact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textGrey, size: compact ? 11 : 13),
            const SizedBox(width: 3),
            Text(
              '$value',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 11 : 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textGrey,
            fontSize: compact ? 9 : 10,
          ),
        ),
      ],
    );
  }
}
