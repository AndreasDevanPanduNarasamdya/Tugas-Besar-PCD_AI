import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'scan_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Pandora Box'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.primaryRed),
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
              const Text(
                'Previously Scanned Models',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // The empty state remains until you perform a real scan
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          color: AppTheme.textDarkGrey.withOpacity(0.5),
                          size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'No scans yet.',
                        style:
                            TextStyle(color: AppTheme.textGrey, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap "Scan Object" to begin.',
                        style: TextStyle(
                            color: AppTheme.textDarkGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // ── Accurate Nav Bar ─────────────────────────────────────────
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.home, color: AppTheme.primaryRed, size: 24),
                SizedBox(height: 4),
                Text('Home',
                    style: TextStyle(color: AppTheme.primaryRed, fontSize: 10)),
              ],
            ),

            // Scan Object (The round red button)
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryRed, // Red background
                      shape: BoxShape.circle, // Round button
                    ),
                    child: const Icon(Icons.crop_free,
                        color: Colors.white, size: 24), // White icon
                  ),
                  const SizedBox(height: 4),
                  const Text('Scan Object',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),

            // Settings
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.settings, color: AppTheme.textGrey, size: 24),
                SizedBox(height: 4),
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
