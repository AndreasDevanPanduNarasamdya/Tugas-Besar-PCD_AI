import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'scan_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> models = [
      {
        'name': 'Car4',
        'faces': '150',
        'vertices': '33',
        'edges': '94',
        'triangles': '33',
        'date': '05 November 2025',
        'size': '431 MB',
      },
      {
        'name': 'Water Bottle',
        'faces': '150',
        'vertices': '33',
        'edges': '94',
        'triangles': '33',
        'date': '05 November 2025',
        'size': '92 MB',
      },
      {
        'name': 'Laptop5',
        'faces': '150',
        'vertices': '33',
        'edges': '94',
        'triangles': '33',
        'date': '05 November 2025',
        'size': '327 MB',
      },
      {
        'name': 'Pringles Can',
        'faces': '150',
        'vertices': '33',
        'edges': '94',
        'triangles': '33',
        'date': '05 November 2025',
        'size': '327 MB',
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        title: SizedBox(
          width: 36,
          height: 36,
          child: CustomPaint(painter: _DiamondLogoPainter()),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Previously Scanned Models',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: models.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final m = models[index];
                    return _ModelCard(model: m);
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Bottom nav bar — pure black, scan button inline but larger ──────
      bottomNavigationBar: SizedBox(
        height: 80,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The actual bar
            Positioned.fill(
              child: Container(color: Colors.black),
            ),

            // Home + spacer + Settings row inside bar
            Positioned.fill(
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        color: AppTheme.primaryRed),
                    const SizedBox(width: 80), // space for the centre button
                    _NavItem(
                        icon: Icons.settings,
                        label: 'Settings',
                        color: AppTheme.textGrey),
                  ],
                ),
              ),
            ),

            // Scan button — centred, protruding 20px above the bar
            Positioned(
              top: -20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    // 1. Halt navigation and ask the OS for permission
                    final status = await Permission.camera.request();

                    if (status.isGranted) {
                      // 2. Permission granted! Safe to spin up ARCore
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScanScreen(),
                          ),
                        );
                      }
                    } else {
                      // 3. Permission denied. Block the crash and tell the user.
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Camera permission is required to scan objects.'),
                            backgroundColor: AppTheme.primaryRed,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.crop_free,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 3),
                      const Text('Scan Object',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nav item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}

// ── Model card ───────────────────────────────────────────────────────────────
class _ModelCard extends StatelessWidget {
  final Map<String, String> model;
  const _ModelCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Container(
              width: 110,
              height: 110,
              color: const Color(0xFF252525),
              child: const Icon(
                Icons.view_in_ar_outlined,
                color: Color(0xFF555555),
                size: 44,
              ),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    model['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Stats — wrapping naturally like the screenshot
                  Text(
                    '${model['faces']} Faces   '
                    '${model['vertices']} Vertices   '
                    '${model['edges']} Edges   '
                    '${model['triangles']}',
                    style: const TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    'Triangles',
                    style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Bottom row: date + size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        model['date']!,
                        style: const TextStyle(
                          color: AppTheme.textDarkGrey,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        model['size']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diamond logo ─────────────────────────────────────────────────────────────
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

    final diamond = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(diamond, paint);

    final ri = r * 0.45;
    final inner = Path()
      ..moveTo(cx, cy - ri)
      ..lineTo(cx + ri, cy)
      ..lineTo(cx, cy + ri)
      ..lineTo(cx - ri, cy)
      ..close();
    canvas.drawPath(inner, paint);

    final nodePaint = Paint()
      ..color = AppTheme.primaryRed
      ..style = PaintingStyle.fill;
    for (final offset in [
      Offset(cx, cy - r),
      Offset(cx + r, cy),
      Offset(cx, cy + r),
      Offset(cx - r, cy),
    ]) {
      canvas.drawCircle(offset, 3.5, nodePaint);
    }
    canvas.drawCircle(Offset(cx, cy), 3.0, nodePaint);

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
