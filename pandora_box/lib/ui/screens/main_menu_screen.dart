import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'scan_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../storage/scan_repository.dart';
import '../../storage/scan_model.dart';
import '../../bloc/scan_bloc.dart';
import 'preview_3d_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  List<ScanModel> _scans = [];

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  void _loadScans() {
    final repo = context.read<ScanRepository>();
    setState(() => _scans = repo.getAllScans());
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> models = [];

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
                child: _scans.isEmpty
                    ? const Center(
                        child: Text(
                          'No scans yet.\nTap the button below to scan an object.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: AppTheme.textGrey, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _scans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _ModelCard(
                              scan: _scans[index],
                              // Change this back to onTap!
                              onTap: () {
                                // 1. Tell the Bloc to load this specific scan from the database
                                context.read<ScanBloc>().add(ScanLoadRequested(
                                    scanId: _scans[index].modelId));

                                // 2. Navigate to the 3D screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    // Ensure 'const' is still removed here!
                                    builder: (_) => Preview3DScreen(),
                                  ),
                                );
                              },
                              onDelete: () async {
                                // ...
                              });
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
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanScreen()),
                        );
                        if (context.mounted) _loadScans();
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
  final ScanModel scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ModelCard({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Delete scan?',
                style: TextStyle(color: Colors.white)),
            content: Text('Permanently delete "${scan.modelName}"?',
                style: const TextStyle(color: AppTheme.textGrey)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.textGrey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Text('Delete',
                    style: TextStyle(color: AppTheme.primaryRed)),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Container(
                width: 110,
                height: 110,
                color: const Color(0xFF252525),
                child: const Icon(Icons.view_in_ar_outlined,
                    color: Color(0xFF555555), size: 44),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scan.modelName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(
                      '${scan.faceCount} Faces   ${scan.vertexCount} Vertices   '
                      '${scan.edgeCount} Edges   ${scan.triangleCount}',
                      style: const TextStyle(
                          color: AppTheme.textGrey, fontSize: 12),
                    ),
                    const Text('Triangles',
                        style:
                            TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(scan.formattedDate,
                            style: const TextStyle(
                                color: AppTheme.textDarkGrey, fontSize: 11)),
                        Text(scan.fileSizeLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
