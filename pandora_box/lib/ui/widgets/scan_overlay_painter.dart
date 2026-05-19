import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Draws the scanning overlay: magenta cylindrical mesh grid + green tracking nodes.
/// Matches the mockup Camera screen exactly.
class ScanOverlayPainter extends CustomPainter {
  final double coveragePercent;
  final List<Offset>?
      trackedPoints; // real projected 2D points from ML (optional)

  ScanOverlayPainter({
    required this.coveragePercent,
    this.trackedPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppTheme.accentMagenta.withOpacity(0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final nodePaint = Paint()
      ..color = AppTheme.accentGreen
      ..style = PaintingStyle.fill;

    final nodeRingPaint = Paint()
      ..color = AppTheme.accentGreen.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final objW = size.width * 0.55;
    final objH = size.height * 0.6;

    // ── Cylindrical vertical curves ──────────────────────────────────────
    // Left curve
    final leftPath = Path();
    leftPath.moveTo(cx - objW / 2, cy - objH / 2);
    leftPath.cubicTo(
      cx - objW * 0.7,
      cy - objH * 0.1,
      cx - objW * 0.7,
      cy + objH * 0.1,
      cx - objW / 2,
      cy + objH / 2,
    );
    canvas.drawPath(leftPath, linePaint);

    // Right curve
    final rightPath = Path();
    rightPath.moveTo(cx + objW / 2, cy - objH / 2);
    rightPath.cubicTo(
      cx + objW * 0.7,
      cy - objH * 0.1,
      cx + objW * 0.7,
      cy + objH * 0.1,
      cx + objW / 2,
      cy + objH / 2,
    );
    canvas.drawPath(rightPath, linePaint);

    // Center vertical line
    canvas.drawLine(
      Offset(cx, cy - objH / 2),
      Offset(cx, cy + objH / 2),
      linePaint,
    );

    // ── Horizontal ellipse rings ──────────────────────────────────────────
    final ringCount = 5;
    for (int i = 0; i < ringCount; i++) {
      final t = i / (ringCount - 1); // 0..1
      final y = cy - objH / 2 + t * objH;
      // Squash the ellipse more near top/bottom (perspective)
      final scaleX = 0.85 + 0.15 * math.sin(t * math.pi);
      final ringRect = Rect.fromCenter(
        center: Offset(cx, y),
        width: objW * scaleX,
        height: objH * 0.12,
      );
      canvas.drawArc(ringRect, 0, math.pi * 2, false, linePaint);
    }

    // ── Vertical grid lines (left/right of center) ────────────────────────
    for (final xOffset in [-objW * 0.28, objW * 0.28]) {
      canvas.drawLine(
        Offset(cx + xOffset, cy - objH / 2),
        Offset(cx + xOffset, cy + objH / 2),
        linePaint..color = AppTheme.accentMagenta.withOpacity(0.5),
      );
    }
    linePaint.color = AppTheme.accentMagenta.withOpacity(0.85);

    // ── Tracking nodes ────────────────────────────────────────────────────
    final nodes = trackedPoints ?? _defaultNodes(cx, cy, objW, objH);

    for (final node in nodes) {
      // Outer ring
      canvas.drawCircle(node, 9, nodeRingPaint);
      // Filled dot
      canvas.drawCircle(node, 5, nodePaint);
    }
  }

  List<Offset> _defaultNodes(double cx, double cy, double objW, double objH) {
    return [
      Offset(cx, cy - objH * 0.38), // top
      Offset(cx - objW * 0.38, cy - objH * 0.15), // top-left
      Offset(cx + objW * 0.32, cy - objH * 0.2), // top-right
      Offset(cx - objW * 0.3, cy + objH * 0.05), // mid-left
      Offset(cx + objW * 0.3, cy + objH * 0.1), // mid-right
      Offset(cx, cy + objH * 0.2), // mid-bottom
      Offset(cx - objW * 0.2, cy + objH * 0.35), // bottom-left
      Offset(cx + objW * 0.18, cy + objH * 0.38), // bottom-right
    ];
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter old) {
    return old.coveragePercent != coveragePercent ||
        old.trackedPoints != trackedPoints;
  }
}
