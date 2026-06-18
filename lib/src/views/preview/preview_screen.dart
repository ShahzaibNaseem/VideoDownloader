import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../viewmodels/home_viewmodel.dart';
import 'widgets/creator_info_card.dart';
import 'widgets/download_actions_card.dart';
import 'widgets/video_preview_card.dart';

class PreviewScreen extends GetView<HomeViewModel> {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Custom Navigation Header Bar (GLOWLOAD TopAppBar)
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.8),
                border: const Border(
                  bottom: BorderSide(color: Colors.white10, width: 1.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  Text(
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.0),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnpaohJYiAbbMj49bFGte7vM1Qm83DZa2mEhnByE_aWjHuZuRUdA8-w2x9XC727eorAanaI1hY6Twd6K8WhH4s9vtzkmW8ULuKnCXQVvJdDWXyr9rkc_qgt6keieG04db6W8K7YMHNO7Na-c-Nl4XGlqupJ_o5CkbXtEh1piHnm_wJc1QRra93jBmFPy-WkS4uhkiTNgsMXX-YNKq5i27pjMbxnzBdTCYpe0KbvyBb_YVEcSOIMJnpeK3HJ-aKlDYZ2h_qMG9gk2I',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Detail Container
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Video Preview Card (aspect ratio 9:16)
                        const VideoPreviewCard(),
                        const SizedBox(height: 24),

                        // Creator & Metadata Info
                        const CreatorInfoCard(),
                        const SizedBox(height: 24),

                        // Action Download Options
                        const DownloadActionsCard(),
                        const SizedBox(height: 28),

                        // Info Tip Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLowest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.0),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pro Tip',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'High-quality downloads may take longer to process based on your connection speed.',
                                      style: GoogleFonts.inter(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
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
