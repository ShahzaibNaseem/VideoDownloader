import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../viewmodels/home_viewmodel.dart';
import 'widgets/download_input_field.dart';
import 'widgets/download_progress_card.dart';
import 'widgets/history_list_item.dart';

class HomeScreen extends GetView<HomeViewModel> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 640;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Atmospheric Background Glows
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: screenWidth * 0.1,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120.0, sigmaY: 120.0),
              child: Container(
                width: isDesktop ? 500 : 300,
                height: isDesktop ? 500 : 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.15,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
              child: Container(
                width: isDesktop ? 300 : 200,
                height: isDesktop ? 300 : 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),

          // 2. Scrollable Canvas
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Navigation
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  snap: true,
                  backgroundColor: AppColors.background.withValues(alpha: 0.8),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: 64,
                  leadingWidth: 56,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: IconButton(
                      onPressed: () {
                        Get.snackbar(
                          'Menu',
                          'Navigation menu simulation...',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.surfaceContainer,
                          colorText: AppColors.textPrimary,
                          margin: const EdgeInsets.all(16),
                        );
                      },
                      icon: const Icon(
                        Icons.menu,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  title: Text(
                    'GLOWLOAD',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: AppColors.primary,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  centerTitle: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 20.0),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuCHZlUwD7ua-Ak_adT-Ogv7ge67s7H93YXC5PprgF3s80XMy0hE_rPn5v6FvCJE53idnxt-XTCKIt9Nz7E4FhvUUiSHmt-cFCCzXNhRpH28rUqOxBaaS8QY_cTqaOodB9xio5w78moRvVyyqFdXUoq1KpzFd2Mi8zz9JGZcOOcpKj41P-phvpl46iMB2A9ojIsaD46ys_FHnkXzFHclmQnxVlNg8vxPb0xTHlR5VTyU_VKMe4xAKB8SoYKcNkoZLuvJZ_rciwAZuyQ',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Main Content
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      
                      // Hero Section
                      Center(
                        child: Column(
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: isDesktop ? 48 : 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  height: 1.15,
                                  color: Colors.white,
                                ),
                                children: [
                                  const TextSpan(text: 'Download anything \nin '),
                                  TextSpan(
                                    text: 'seconds',
                                    style: GoogleFonts.inter(
                                      color: AppColors.primary,
                                      fontStyle: FontStyle.italic,
                                      shadows: [
                                        Shadow(
                                          color: AppColors.primary.withValues(alpha: 0.4),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 450),
                              child: Text(
                                'The fastest way to grab high-quality content from your favorite platforms.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: isDesktop ? 18 : 16,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Input Section
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: const DownloadInputField(),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Platform Chips Section
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'SUPPORTED PLATFORMS',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildPlatformChip(
                                  icon: Icons.play_circle,
                                  label: 'TikTok',
                                  color: AppColors.primary,
                                ),
                                _buildPlatformChip(
                                  icon: Icons.photo_camera,
                                  label: 'Instagram',
                                  color: AppColors.secondary,
                                ),
                                _buildPlatformChip(
                                  icon: Icons.smart_display_rounded,
                                  label: 'YouTube',
                                  color: const Color(0xFFFF4444),
                                ),
                                _buildPlatformChip(
                                  icon: Icons.movie,
                                  label: 'Reels',
                                  color: AppColors.tertiary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Active Download & History section
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DownloadProgressCard(),
                            ],
                          ),
                        ),
                      ),

                      // Bento Feature Grid
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildBentoCardLossless(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: _buildBentoCardSecurity(),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildBentoCardLossless(),
                                    const SizedBox(height: 16),
                                    _buildBentoCardSecurity(),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // History Header Title
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Download History',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Obx(() => Text(
                                        '${controller.downloadHistory.length} items',
                                        style: GoogleFonts.inter(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                        ),
                                      )),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),

                // History List Items
                Obx(() {
                  final history = controller.downloadHistory;
                  if (history.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 680),
                          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border, width: 1),
                                ),
                                child: const Icon(
                                  Icons.download_done_rounded,
                                  color: AppColors.textMuted,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No downloads yet',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your saved Instagram, TikTok & YouTube media will appear here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverAlignHistoryList(history: history),
                  );
                }),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 48),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Supported Platform Chip Builder
  Widget _buildPlatformChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Bento Card 1: Lossless Quality
  Widget _buildBentoCardLossless() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
        image: const DecorationImage(
          image: NetworkImage(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuChxU6Z05w6sRXEB2Jo73qYCH0VELLXs8Xwg3Hf9LFpn4VCROnG30pyptmb1RsTvZnM3OLNiapeo9cPMvy4V6P9BSNxdKMatwyVJZsjA2OIGciOIWo3DjZIaH1kEGNYaAq-VmRN3S1NkC7mxTFQgE_Jkpb3MAskMsLvLpkBHx_TQ5D9BC4tnn0xcEFIfx6X1bOt-taDJuVvJHFJYpvj8tvfPI2GWEtmwWempUmRQQMtpUmSA1b6IN7eWr_X_RNmu0_7T9kYWNOzCNU',
          ),
          fit: BoxFit.cover,
          opacity: 0.25,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lossless Quality',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We preserve the original bitrate and resolution for every download.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bento Card 2: Safe & Anonymous
  Widget _buildBentoCardSecurity() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.security_rounded,
            color: Colors.white,
            size: 40,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safe & Anonymous',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No account needed. Just paste and glow.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Separate Sliver Align Helper to constrain history width on wider devices
class SliverAlignHistoryList extends StatelessWidget {
  final List<dynamic> history;

  const SliverAlignHistoryList({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView.builder(
            itemCount: history.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final item = history[index];
              return HistoryListItem(item: item);
            },
          ),
        ),
      ),
    );
  }
}
