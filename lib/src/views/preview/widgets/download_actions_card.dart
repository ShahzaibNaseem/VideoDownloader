import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/app_colors.dart';
import '../../../models/download_item.dart';
import '../../../viewmodels/home_viewmodel.dart';

class DownloadActionsCard extends GetView<HomeViewModel> {
  const DownloadActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final item = controller.activePreviewItem.value;
      if (item == null) return const SizedBox.shrink();

      final qualityOptions = item.qualityOptions;

      // Always show static buttons, but grey out ones not available
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Primary — No Watermark
          _DownloadButton(
            label: 'Download Without Watermark',
            icon: Icons.check_circle_outline_rounded,
            style: _ButtonStyle.primary,
            isAvailable: qualityOptions.containsKey('No Watermark'),
            onTap: () => controller.startBackgroundDownload('No Watermark'),
          ),
          const SizedBox(height: 16),

          // 2. HD (TikTok only, may not always differ from No Watermark)
          if (qualityOptions.containsKey('HD')) ...[
            _DownloadButton(
              label: 'Download HD',
              icon: Icons.hd_rounded,
              style: _ButtonStyle.outlined,
              isAvailable: true,
              onTap: () => controller.startBackgroundDownload('HD'),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Instagram Direct (generic single download)
          if (qualityOptions.containsKey('Download') && !qualityOptions.containsKey('No Watermark')) ...[
            _DownloadButton(
              label: 'Download',
              icon: Icons.download_rounded,
              style: _ButtonStyle.primary,
              isAvailable: true,
              onTap: () => controller.startBackgroundDownload('Download'),
            ),
            const SizedBox(height: 16),
          ],

          // 4. Carousel items (Instagram carousel posts)
          if (item.type == DownloadType.carousel) ...[
            ...qualityOptions.entries.where((e) => e.key.startsWith('Item ')).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DownloadButton(
                  label: 'Download ${entry.key}',
                  icon: Icons.photo_library_rounded,
                  style: _ButtonStyle.outlined,
                  isAvailable: true,
                  onTap: () => controller.startBackgroundDownload(entry.key),
                ),
              );
            }),
          ],

          // 5. Watermarked (TikTok only)
          if (qualityOptions.containsKey('Watermarked')) ...[
            _DownloadButton(
              label: 'Download with Watermark',
              icon: Icons.branding_watermark_rounded,
              style: _ButtonStyle.subtle,
              isAvailable: true,
              onTap: () => controller.startBackgroundDownload('Watermarked'),
            ),
          ],
        ],
      );
    });
  }
}

enum _ButtonStyle { primary, outlined, subtle }

class _DownloadButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ButtonStyle style;
  final bool isAvailable;
  final VoidCallback onTap;

  const _DownloadButton({
    required this.label,
    required this.icon,
    required this.style,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double height = style == _ButtonStyle.subtle ? 54 : 60;

    BoxDecoration decoration;
    Color iconColor;
    Color textColor;

    if (!isAvailable) {
      decoration = BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.0),
      );
      iconColor = AppColors.textSecondary.withValues(alpha: 0.4);
      textColor = AppColors.textSecondary.withValues(alpha: 0.4);
    } else {
      switch (style) {
        case _ButtonStyle.primary:
          decoration = BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          );
          iconColor = Colors.white;
          textColor = Colors.white;
          break;
        case _ButtonStyle.outlined:
          decoration = BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary, width: 2.0),
          );
          iconColor = AppColors.primary;
          textColor = AppColors.primary;
          break;
        case _ButtonStyle.subtle:
          decoration = BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
          );
          iconColor = AppColors.textSecondary;
          textColor = AppColors.textSecondary;
          break;
      }
    }

    return Container(
      height: height,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: style == _ButtonStyle.subtle ? 14 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
