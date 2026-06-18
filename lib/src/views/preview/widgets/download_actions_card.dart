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
      final bool isYouTube = item.platform == MediaPlatform.youtube;
      final bool isTikTok = item.platform == MediaPlatform.tiktok;

      // ── YouTube: show all available quality options as buttons ───────────────
      if (isYouTube) {
        return _buildYouTubeButtons(qualityOptions);
      }

      // ── TikTok ───────────────────────────────────────────────────────────────
      if (isTikTok) {
        return _buildTikTokButtons(qualityOptions);
      }

      // ── Instagram ─────────────────────────────────────────────────────────────
      return _buildInstagramButtons(item, qualityOptions);
    });
  }

  Widget _buildYouTubeButtons(Map<String, String> qualityOptions) {
    // Quality priority order for display
    const List<String> qualityPriority = [
      '4K (2160p)',
      'QHD (1440p)',
      'Full HD (1080p)',
      'HD (720p)',
      'SD (480p)',
      'Low (360p)',
      'Lowest (240p)',
    ];

    final availableQualities = qualityPriority.where((q) => qualityOptions.containsKey(q)).toList();

    // Add any keys not in the priority list
    for (final key in qualityOptions.keys) {
      if (!qualityPriority.contains(key)) {
        availableQualities.add(key);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'SELECT QUALITY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ),
        ...availableQualities.asMap().entries.map((entry) {
          final index = entry.key;
          final quality = entry.value;
          final bool isTop = index == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DownloadButton(
              label: isTop ? '$quality  ★ Best' : quality,
              icon: _ytQualityIcon(quality),
              style: isTop ? _ButtonStyle.primary : _ButtonStyle.outlined,
              isAvailable: true,
              onTap: () => controller.startBackgroundDownload(quality),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTikTokButtons(Map<String, String> qualityOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HD (No Watermark) — highest quality TikTok
        if (qualityOptions.containsKey('HD (No Watermark)')) ...[
          _DownloadButton(
            label: 'Download HD · No Watermark',
            icon: Icons.hd_rounded,
            style: _ButtonStyle.primary,
            isAvailable: true,
            onTap: () => controller.startBackgroundDownload('HD (No Watermark)'),
          ),
          const SizedBox(height: 16),
        ],

        // No Watermark fallback (SD version when HD differs)
        if (qualityOptions.containsKey('No Watermark')) ...[
          _DownloadButton(
            label: 'Download · No Watermark',
            icon: Icons.check_circle_outline_rounded,
            style: qualityOptions.containsKey('HD (No Watermark)')
                ? _ButtonStyle.outlined
                : _ButtonStyle.primary,
            isAvailable: true,
            onTap: () => controller.startBackgroundDownload('No Watermark'),
          ),
          const SizedBox(height: 16),
        ],

        // Watermarked
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
  }

  Widget _buildInstagramButtons(DownloadItem item, Map<String, String> qualityOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary — No Watermark
        _DownloadButton(
          label: 'Download Without Watermark',
          icon: Icons.check_circle_outline_rounded,
          style: _ButtonStyle.primary,
          isAvailable: qualityOptions.containsKey('No Watermark'),
          onTap: () => controller.startBackgroundDownload('No Watermark'),
        ),
        const SizedBox(height: 16),

        // Instagram Direct (generic single download)
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

        // Carousel items (Instagram carousel posts)
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
      ],
    );
  }

  IconData _ytQualityIcon(String quality) {
    if (quality.contains('4K') || quality.contains('2160')) return Icons.four_k_rounded;
    if (quality.contains('1440')) return Icons.high_quality_rounded;
    if (quality.contains('1080')) return Icons.hd_rounded;
    if (quality.contains('720')) return Icons.hd_rounded;
    return Icons.sd_rounded;
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
