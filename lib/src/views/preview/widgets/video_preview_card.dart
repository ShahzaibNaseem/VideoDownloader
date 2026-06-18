import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../../constants/app_colors.dart';
import '../../../viewmodels/home_viewmodel.dart';
import '../../../models/download_item.dart';

class VideoPreviewCard extends StatefulWidget {
  const VideoPreviewCard({super.key});

  @override
  State<VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<VideoPreviewCard> {
  final HomeViewModel controller = Get.find<HomeViewModel>();
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  double _progress = 0.0;
  String? _initializedUrl;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() async {
    final item = controller.activePreviewItem.value;
    if (item == null || item.type != DownloadType.video) return;

    final String videoUrl = item.qualityOptions['No Watermark'] ??
        item.qualityOptions['Download'] ??
        item.qualityOptions['HD'] ??
        item.qualityOptions.values.firstWhere((v) => v.isNotEmpty && v.startsWith('http'), orElse: () => '');

    if (videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    _initializedUrl = videoUrl;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    try {
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();
      
      _videoController!.addListener(_videoListener);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint("Video player initialization failed: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController == null) return;
    if (mounted) {
      setState(() {
        _progress = _videoController!.value.duration.inMilliseconds > 0
            ? _videoController!.value.position.inMilliseconds /
                _videoController!.value.duration.inMilliseconds
            : 0.0;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final item = controller.activePreviewItem.value;
      if (item == null) return const SizedBox.shrink();

      // Cyberpunk default image fallback
      const String fallbackImage =
          'https://lh3.googleusercontent.com/aida-public/AB6AXuC_vaW9mCCtcnJk132bOcMuKItXeEFkz9bpe8MPzYlG04uMFoxW83120Kxji6VCy8B8zT58GRdSqSZ256LKhfNYF6A9y3NUmuSXHxnT2kb2jgr_BmH_2eDUG4uwu4B0bobWpViwLcx8sVffe7oEeTsUgIm6BI-XQ-9IZcdfl1kvDnVDkGbPdviLSzO_l9Zyy9vjCbLO2HLGCR8wKxxTzHRQfi0fYt6r9LsNrfkr80tppl7Ir1i7_d9vt080r8-kaWaQJLErHlkXlhU';

      final String imageUrl = item.thumbnailUrl.isNotEmpty ? item.thumbnailUrl : fallbackImage;
      final bool isTikTok = item.url.contains('tiktok.com');

      // Re-initialize if the preview item changes
      final String currentVideoUrl = item.qualityOptions['No Watermark'] ??
          item.qualityOptions['Download'] ??
          item.qualityOptions['HD'] ??
          item.qualityOptions.values.firstWhere((v) => v.isNotEmpty && v.startsWith('http'), orElse: () => '');
      
      if (item.type == DownloadType.video && 
          currentVideoUrl != _initializedUrl) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _videoController?.removeListener(_videoListener);
          _videoController?.dispose();
          _isInitialized = false;
          _isPlaying = false;
          _hasError = false;
          _progress = 0.0;
          _initializePlayer();
        });
      }

      return AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 1. Background Thumbnail Image (serves as placeholder until video loads)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.network(
                        fallbackImage,
                        fit: BoxFit.cover,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.surfaceContainer,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Video Player Overlay
              if (item.type == DownloadType.video && _isInitialized && _videoController != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  ),
                ),

              // 3. Play/Pause Tap Target Overlay
              if (item.type == DownloadType.video)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(),
                  ),
                ),

              // 4. Play Icon Overlay in Center (only if not playing, or loading)
              if (item.type == DownloadType.video && !_isPlaying && !_hasError)
                Center(
                  child: IgnorePointer(
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.2),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Loading spinner during video player initialization
              if (item.type == DownloadType.video && !_isInitialized && !_hasError)
                Center(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
                ),

              // 6. Platform Badge Overlay (Top Left)
              Positioned(
                top: 16,
                left: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTikTok ? Icons.play_circle_outline : Icons.camera_alt_outlined,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isTikTok ? 'TikTok' : 'Instagram',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 7. Video Progress Bar (Bottom)
              if (item.type == DownloadType.video && _isInitialized && _videoController != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
