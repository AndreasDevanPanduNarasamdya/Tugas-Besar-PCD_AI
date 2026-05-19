import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_card.dart';
import '../../storage/scan_model.dart'; // FIXED: Proper relative import
import 'scan_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  // ── Demo data - mapped perfectly to your Hive ScanModel ────────────────
  static final List<ScanModel> _demoScans = [
    ScanModel()
      ..modelId = '1'
      ..modelName = 'Car4'
      ..timestamp = DateTime(2025, 11, 5)
      ..fileSizeMb = 431.0
      ..faceCount = 150
      ..vertexCount = 33
      ..edgeCount = 94
      ..triangleCount = 33,
    ScanModel()
      ..modelId = '2'
      ..modelName = 'Water Bottle'
      ..timestamp = DateTime(2025, 11, 5)
      ..fileSizeMb = 92.0
      ..faceCount = 150
      ..vertexCount = 33
      ..edgeCount = 94
      ..triangleCount = 33,
    ScanModel()
      ..modelId = '3'
      ..modelName = 'Laptop5'
      ..timestamp = DateTime(2025, 11, 5)
      ..fileSizeMb = 327.0
      ..faceCount = 150
      ..vertexCount = 33
      ..edgeCount = 94
      ..triangleCount = 33,
    ScanModel()
      ..modelId = '4'
      ..modelName = 'Pringles Can'
      ..timestamp = DateTime(2025, 11, 5)
      ..fileSizeMb = 327.0
      ..faceCount = 150
      ..vertexCount = 33
      ..edgeCount = 94
      ..triangleCount = 33,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Pandora Box'),
        actions: [
          IconButton(
            // FIXED: Removed const
            icon: Icon(Icons.settings, color: AppTheme.primaryRed),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIXED: Removed const
              Text(
                'Previously Scanned Models',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // Scan list
              Expanded(
                child: ListView.builder(
                  itemCount: _demoScans.length,
                  itemBuilder: (context, index) {
                    final scan = _demoScans[index];
                    return ScanCard(
                      name: scan.modelName,
                      dateStr:
                          scan.formattedDate, // Uses your ScanModel getter!
                      fileSizeLabel: scan.fileSizeLabel,
                      faceCount: scan.faceCount,
                      vertexCount: scan.vertexCount,
                      edgeCount: scan.edgeCount,
                      triangleCount: scan.triangleCount,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.cardBackground,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home (left - active)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIXED: Removed const
                Icon(Icons.home, color: AppTheme.primaryRed, size: 24),
                const SizedBox(height: 2),
                Text('Home',
                    style: TextStyle(color: AppTheme.primaryRed, fontSize: 10)),
              ],
            ),

            // Scan Object (center - prominent)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      // FIXED: Removed const
                      border:
                          Border.all(color: AppTheme.primaryRed, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.crop_free,
                        color: AppTheme.primaryRed, size: 22),
                  ),
                  const SizedBox(height: 2),
                  Text('Scan Object',
                      style:
                          TextStyle(color: AppTheme.primaryRed, fontSize: 10)),
                ],
              ),
            ),

            // Settings
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIXED: Removed const
                Icon(Icons.settings, color: AppTheme.textGrey, size: 24),
                const SizedBox(height: 2),
                Text('Settings',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
