import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../viewmodels/home_viewmodel.dart';
import 'widgets/circular_progress_painter.dart';

class DownloadingScreen extends GetView<HomeViewModel> {
  const DownloadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 640;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Atmospheric Drifting Mesh Background
          Positioned(
            top: -100,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 140.0, sigmaY: 140.0),
              child: Container(
                width: screenWidth * 0.6,
                height: screenWidth * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 120.0, sigmaY: 120.0),
              child: Container(
                width: screenWidth * 0.5,
                height: screenWidth * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          // Radial glow behind loader
          Center(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),

          // 2. Main Progress Display
          SafeArea(
            child: Obx(() {
              final download = controller.currentDownload.value;
              final double progressVal = download?.progress ?? 0.0;
              final int percent = (progressVal * 100).toInt();

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CenterAnchor.crossAxisAlignment, // center alignment
                children: [
                  const Spacer(),

                  // Circular Progress Ring
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: isDesktop ? 320 : 256,
                          height: isDesktop ? 320 : 256,
                          child: CustomPaint(
                            painter: CircularProgressPainter(
                              progress: progressVal,
                              trackColor: AppColors.surfaceContainer,
                              progressColor: AppColors.primaryContainer,
                              strokeWidth: 8.0,
                            ),
                          ),
                        ),
                        // Inner Percentage Text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percent%',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: isDesktop ? 64 : 54,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2.0,
                              ),
                            ),
                            Text(
                              'Downloaded',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.textSecondary.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Status Message
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BouncingIcon(),
                      const SizedBox(width: 8),
                      Text(
                        'Saving to gallery...',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      'Removing watermarks and optimizing for high-quality playback.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Cancel Button
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: controller.cancelDownload,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Cancel',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// Bouncing Download Icon Stateful Helper
class BouncingIcon extends StatefulWidget {
  const BouncingIcon({super.key});

  @override
  State<BouncingIcon> createState() => _BouncingIconState();
}

class _BouncingIconState extends State<BouncingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: const Icon(
            Icons.download_rounded,
            color: AppColors.primaryContainer,
            size: 22,
          ),
        );
      },
    );
  }
}

// Custom Center Cross Alignment Anchor helper for compile safety
class CenterAnchor {
  CenterAnchor._();
  static const CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center;
}
