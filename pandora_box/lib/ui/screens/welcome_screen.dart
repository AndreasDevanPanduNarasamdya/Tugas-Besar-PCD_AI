import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'main_menu_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // ── Logo row ───────────────────────────────────────────────
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CustomPaint(painter: _DiamondLogoPainter()),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Welcome To',
                          style: TextStyle(
                              color: AppTheme.textGrey, fontSize: 13)),
                      Text('Pandora Box',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Text('Make your real objects to 3D',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),

              const SizedBox(height: 32),

              // ── Phone mockup ───────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateY(-0.38) // tilt left like the image
                      ..rotateZ(0.04), // subtle clockwise lean
                    child: Container(
                      width: 220,
                      height: 420,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0A),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                            color: const Color(0xFF2A2A2A), width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.primaryRed.withOpacity(0.18),
                              blurRadius: 50,
                              spreadRadius: 8),
                          BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 30,
                              offset: const Offset(10, 20)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(33),
                        child: Stack(
                          children: [
                            // Screen background
                            Container(color: const Color(0xFF111111)),

                            // Notch
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 80,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A0A0A),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(14),
                                      bottomRight: Radius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // QR code in centre
                            Center(
                              child: SizedBox(
                                width: 150,
                                height: 150,
                                child: CustomPaint(painter: _QRCodePainter()),
                              ),
                            ),

                            // Bottom red bar (like a CTA strip visible in mockup)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 52,
                                color: AppTheme.primaryRed,
                                child: const Center(
                                  child: Text(
                                    'Scan to start',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Description ────────────────────────────────────────────
              const Center(
                child: Text(
                  'Discover what you can do with a phone\nand an object. Explore how you can\nmake reality to digital.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textGrey, fontSize: 13, height: 1.6),
                ),
              ),

              const SizedBox(height: 28),

              // ── Continue button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Diamond / node logo matching the image ─────────────────────────────────
class _DiamondLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryRed
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // Outer diamond
    final diamond = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(diamond, paint);

    // Inner smaller diamond
    final ri = r * 0.45;
    final inner = Path()
      ..moveTo(cx, cy - ri)
      ..lineTo(cx + ri, cy)
      ..lineTo(cx, cy + ri)
      ..lineTo(cx - ri, cy)
      ..close();
    canvas.drawPath(inner, paint);

    // Corner nodes (filled circles at diamond tips)
    final nodePaint = Paint()
      ..color = AppTheme.primaryRed
      ..style = PaintingStyle.fill;
    const nr = 3.5;
    for (final offset in [
      Offset(cx, cy - r),
      Offset(cx + r, cy),
      Offset(cx, cy + r),
      Offset(cx - r, cy),
    ]) {
      canvas.drawCircle(offset, nr, nodePaint);
    }

    // Centre dot
    canvas.drawCircle(Offset(cx, cy), 3.0, nodePaint);

    // Lines from inner diamond to outer tips
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawLine(Offset(cx, cy - ri), Offset(cx, cy - r), paint);
    canvas.drawLine(Offset(cx + ri, cy), Offset(cx + r, cy), paint);
    canvas.drawLine(Offset(cx, cy + ri), Offset(cx, cy + r), paint);
    canvas.drawLine(Offset(cx - ri, cy), Offset(cx - r, cy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Realistic-looking QR code painter ─────────────────────────────────────
class _QRCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final black = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final s = size.width;
    final cell = s / 21; // standard QR uses 21×21 modules

    // Helper: draw a filled cell
    void drawCell(int col, int row) {
      canvas.drawRect(
        Rect.fromLTWH(col * cell + 0.5, row * cell + 0.5, cell - 1, cell - 1),
        black,
      );
    }

    // Helper: draw a finder pattern (7×7) at grid position (startCol, startRow)
    void drawFinder(int startCol, int startRow) {
      // Outer 7×7 border
      for (int c = 0; c < 7; c++) {
        for (int r = 0; r < 7; r++) {
          if (r == 0 || r == 6 || c == 0 || c == 6) {
            drawCell(startCol + c, startRow + r);
          }
        }
      }
      // Inner 3×3 solid
      for (int c = 2; c <= 4; c++) {
        for (int r = 2; r <= 4; r++) {
          drawCell(startCol + c, startRow + r);
        }
      }
    }

    // Three finder patterns
    drawFinder(0, 0); // top-left
    drawFinder(14, 0); // top-right
    drawFinder(0, 14); // bottom-left

    // Timing patterns (alternating between finders)
    for (int i = 8; i <= 12; i++) {
      if (i % 2 == 0) {
        drawCell(i, 6);
        drawCell(6, i);
      }
    }

    // Simulated data modules (pseudo-random but visually realistic)
    final rand = math.Random(42);
    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        // Skip finder pattern zones + separators
        if (r < 8 && c < 8) continue;
        if (r < 8 && c > 12) continue;
        if (r > 12 && c < 8) continue;
        // Skip timing rows/cols
        if (r == 6 || c == 6) continue;
        if (rand.nextDouble() > 0.5) drawCell(c, r);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
