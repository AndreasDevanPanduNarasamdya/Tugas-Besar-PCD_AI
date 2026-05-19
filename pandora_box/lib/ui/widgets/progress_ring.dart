import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';

class ScanProgressRing extends StatelessWidget {
  final double percent; // 0..100
  final int pointCount;

  const ScanProgressRing({
    super.key,
    required this.percent,
    required this.pointCount,
  });

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: 36.0,
      lineWidth: 5.0,
      percent: (percent / 100).clamp(0.0, 1.0),
      backgroundColor: AppTheme.cardBackground,
      progressColor: AppTheme.primaryRed,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${percent.toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_formatPts(pointCount)}pts',
            style: TextStyle(
              color: AppTheme.textGrey,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPts(int pts) {
    if (pts >= 1000) return '${(pts / 1000).toStringAsFixed(1)}k';
    return '$pts';
  }
}
