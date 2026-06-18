import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../models/download_item.dart';
import '../../../viewmodels/home_viewmodel.dart';

class CreatorInfoCard extends GetView<HomeViewModel> {
  const CreatorInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final item = controller.activePreviewItem.value;
      if (item == null) return const SizedBox.shrink();

      final String displayAuthor = item.authorName.isNotEmpty
          ? '@${item.authorName}'
          : _platformLabel(item.platform);

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left: Creator & Platform
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayAuthor,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _platformIcon(item.platform),
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _platformLabel(item.platform),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (item.fileSize.isNotEmpty && item.fileSize != 'Checking...') ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.storage_rounded,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.fileSize,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Right: Action Buttons (Share, Bookmark)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(
                icon: Icons.share_rounded,
                onPressed: () {
                  Get.snackbar(
                    'Share',
                    'Sharing options triggered...',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.surfaceContainer,
                    colorText: AppColors.textPrimary,
                    margin: const EdgeInsets.all(16),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildIconButton(
                icon: Icons.bookmark_border_rounded,
                onPressed: () {
                  Get.snackbar(
                    'Bookmark',
                    'Added to saved collection!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.surfaceContainer,
                    colorText: AppColors.textPrimary,
                    margin: const EdgeInsets.all(16),
                  );
                },
              ),
            ],
          ),
        ],
      );
    });
  }

  String _platformLabel(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.tiktok:
        return 'TikTok';
      case MediaPlatform.instagram:
        return 'Instagram';
      case MediaPlatform.youtube:
        return 'YouTube';
      case MediaPlatform.unknown:
        return 'Social Media';
    }
  }

  IconData _platformIcon(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.tiktok:
        return Icons.music_note_rounded;
      case MediaPlatform.instagram:
        return Icons.camera_alt_rounded;
      case MediaPlatform.youtube:
        return Icons.smart_display_rounded;
      case MediaPlatform.unknown:
        return Icons.public_rounded;
    }
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
