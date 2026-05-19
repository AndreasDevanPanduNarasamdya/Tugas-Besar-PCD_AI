import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card for each item in the "Previously Scanned Models" list.
/// Matches mockup: thumbnail on left, name + stats, date + file size on right.
class ScanCard extends StatelessWidget {
  final String name;
  final String dateStr;
  final String fileSizeLabel;
  final int faceCount;
  final int vertexCount;
  final int edgeCount;
  final int triangleCount;
  final Uint8List? thumbnail;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ScanCard({
    super.key,
    required this.name,
    required this.dateStr,
    required this.fileSizeLabel,
    required this.faceCount,
    required this.vertexCount,
    required this.edgeCount,
    required this.triangleCount,
    this.thumbnail,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbnail != null
                  ? Image.memory(
                      thumbnail!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.view_in_ar,
                        color: AppTheme.primaryRed,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Name + stats + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$faceCount Faces   $vertexCount Vertices   $edgeCount Edges   $triangleCount Triangles',
                    style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: AppTheme.textDarkGrey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // File size + optional delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onDelete != null)
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.more_vert,
                        color: AppTheme.textDarkGrey, size: 16),
                  ),
                const SizedBox(height: 8),
                Text(
                  fileSizeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
