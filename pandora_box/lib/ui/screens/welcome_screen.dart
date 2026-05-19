import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
                  // Red diamond / cube icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: AppTheme.primaryRed, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.view_in_ar,
                        color: AppTheme.primaryRed, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome To',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Pandora Box',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.15),

              const SizedBox(height: 8),
              Text(
                'Make your real objects to 3D',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 13,
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 500.ms),

              const SizedBox(height: 32),

              // ── Phone mockup ───────────────────────────────────────────
              Expanded(
                child: Center(
                  child: _PhoneMockup()
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 700.ms)
                      .slideY(begin: 0.1),
                ),
              ),

              const SizedBox(height: 24),

              // ── Description ────────────────────────────────────────────
              Center(
                child: Text(
                  'Discover what you can do with a phone\nand an object. Explore how you can\nmake reality to digital.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

              const SizedBox(height: 28),

              // ── Continue button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                    );
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ).animate().fadeIn(delay: 550.ms, duration: 500.ms),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 320,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cardBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Dark screen background
            Container(color: const Color(0xFF111111)),

            // Simulated scan screen content
            Column(
              children: [
                // Fake status bar
                Container(
                  height: 24,
                  color: Colors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(5),
                          border:
                              Border.all(color: AppTheme.cardBorder, width: 1),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    color: const Color(0xFF0A0A0A),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // QR-like grid pattern representing scan overlay
                          _buildQRPlaceholder(),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primaryRed),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Scanning...',
                              style: TextStyle(
                                color: AppTheme.primaryRed,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom red button
                Container(
                  height: 40,
                  color: Colors.black,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRPlaceholder() {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _QRPatternPainter()),
    );
  }
}

class _QRPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryRed.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final s = size.width;
    // Corner squares
    for (final (x, y) in [(0.0, 0.0), (s * 0.65, 0.0), (0.0, s * 0.65)]) {
      canvas.drawRect(Rect.fromLTWH(x, y, s * 0.3, s * 0.3), paint);
      canvas.drawRect(
          Rect.fromLTWH(x + s * 0.07, y + s * 0.07, s * 0.16, s * 0.16),
          paint
            ..style = PaintingStyle.fill
            ..color = AppTheme.primaryRed.withOpacity(0.5));
      paint.style = PaintingStyle.stroke;
      paint.color = AppTheme.primaryRed.withOpacity(0.7);
    }

    // Grid lines
    for (int i = 1; i <= 6; i++) {
      final pos = i * s / 7;
      canvas.drawLine(Offset(pos, 0), Offset(pos, s), paint..strokeWidth = 0.5);
      canvas.drawLine(Offset(0, pos), Offset(s, pos), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
