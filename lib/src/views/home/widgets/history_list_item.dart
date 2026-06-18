import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../models/download_item.dart';
import '../../../viewmodels/home_viewmodel.dart';

class HistoryListItem extends GetView<HomeViewModel> {
  final DownloadItem item;

  const HistoryListItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == DownloadStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Row(
        children: [
          // Image Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Image.network(
                item.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.surfaceContainer,
                    child: const Icon(
                      Icons.image_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info (Title, size, type)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isCompleted ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.none : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      item.type == DownloadType.video ? Icons.play_arrow_rounded : Icons.photo_rounded,
                      color: AppColors.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.fileSize,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Text(
                      item.status == DownloadStatus.completed
                          ? 'Saved'
                          : 'Failed',
                      style: GoogleFonts.spaceGrotesk(
                        color: item.status == DownloadStatus.completed
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompleted)
                IconButton(
                  onPressed: () {
                    Get.snackbar(
                      'Preview',
                      'Opening media player simulation...',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.surfaceContainer,
                      colorText: AppColors.textPrimary,
                      margin: const EdgeInsets.all(16),
                    );
                  },
                  icon: const Icon(
                    Icons.folder_open_rounded,
                    color: AppColors.primaryContainer,
                    size: 20,
                  ),
                  tooltip: 'Open File',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              IconButton(
                onPressed: () => controller.deleteFromHistory(item.id),
                icon: const Icon(
                  Icons.delete_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                tooltip: 'Delete',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
