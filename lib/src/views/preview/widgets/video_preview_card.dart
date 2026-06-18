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
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  String? _initializedUrl;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() async {
    final item = controller.activePreviewItem.value;
    if (item == null || item.type != DownloadType.video) return;

    // For YouTube, skip inline preview (stream URLs need auth headers that
    // video_player can't set). Show thumbnail + duration badge instead.
    if (item.platform == MediaPlatform.youtube) {
      if (mounted) {
        setState(() {
          _hasError = false;
          _isInitialized = false;
          // Pre-populate duration from metadata
          _totalDuration = Duration(seconds: item.durationSeconds);
        });
      }
      return;
    }

    // Pick the highest-quality URL available for preview
    final String videoUrl = item.qualityOptions['HD (No Watermark)'] ??
        item.qualityOptions['No Watermark'] ??
        item.qualityOptions['Download'] ??
        item.qualityOptions['HD'] ??
        item.qualityOptions.values.firstWhere(
            (v) => v.isNotEmpty && v.startsWith('http'),
            orElse: () => '');

    if (videoUrl.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    _initializedUrl = videoUrl;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    // Pre-populate duration from API metadata so it shows immediately
    if (item.durationSeconds > 0) {
      setState(() {
        _totalDuration = Duration(seconds: item.durationSeconds);
      });
    }

    try {
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();

      _videoController!.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
          // Use player duration (accurate) once initialized
          _totalDuration = _videoController!.value.duration;
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
        final dur = _videoController!.value.duration;
        final pos = _videoController!.value.position;
        _totalDuration = dur.inMilliseconds > 0 ? dur : _totalDuration;
        _currentPosition = pos;
        _progress = _totalDuration.inMilliseconds > 0
            ? pos.inMilliseconds / _totalDuration.inMilliseconds
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

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '0:00';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
      final bool isTikTok = item.platform == MediaPlatform.tiktok;
      final bool isYouTube = item.platform == MediaPlatform.youtube;

      // Re-initialize if the preview item changes (and it's not YouTube)
      final String currentVideoUrl = item.qualityOptions['HD (No Watermark)'] ??
          item.qualityOptions['No Watermark'] ??
          item.qualityOptions['Download'] ??
          item.qualityOptions['HD'] ??
          item.qualityOptions.values.firstWhere(
              (v) => v.isNotEmpty && v.startsWith('http'),
              orElse: () => '');

      if (item.type == DownloadType.video &&
          !isYouTube &&
          currentVideoUrl != _initializedUrl) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _videoController?.removeListener(_videoListener);
          _videoController?.dispose();
          _isInitialized = false;
          _isPlaying = false;
          _hasError = false;
          _progress = 0.0;
          _currentPosition = Duration.zero;
          _totalDuration = Duration(seconds: item.durationSeconds);
          _initializePlayer();
        });
      }

      // Determine platform display info
      String platformLabel;
      IconData platformIcon;
      Color platformColor;
      if (isYouTube) {
        platformLabel = 'YouTube';
        platformIcon = Icons.smart_display_rounded;
        platformColor = const Color(0xFFFF4444);
      } else if (isTikTok) {
        platformLabel = 'TikTok';
        platformIcon = Icons.play_circle_outline;
        platformColor = AppColors.primary;
      } else {
        platformLabel = 'Instagram';
        platformIcon = Icons.camera_alt_outlined;
        platformColor = AppColors.primary;
      }

      // Duration to display — prefer live player value once initialized
      final Duration displayDuration = _totalDuration.inSeconds > 0
          ? _totalDuration
          : Duration(seconds: item.durationSeconds);

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

              // 2. Video Player Overlay (only for non-YouTube)
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

              // 3. Play/Pause Tap Target Overlay (not for YouTube — no inline preview)
              if (item.type == DownloadType.video && !isYouTube)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(),
                  ),
                ),

              // 4. YouTube icon overlay — signals "preview not available, download to watch"
              if (isYouTube)
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
                            color: const Color(0xFFFF4444).withValues(alpha: 0.25),
                            border: Border.all(
                                color: const Color(0xFFFF4444).withValues(alpha: 0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF4444).withValues(alpha: 0.3),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.smart_display_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Play Icon Overlay in Center (only if not playing, or loading — non-YouTube)
              if (item.type == DownloadType.video && !_isPlaying && !_hasError && !isYouTube)
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

              // 6. Loading spinner during video player initialization (non-YouTube only)
              if (item.type == DownloadType.video && !_isInitialized && !_hasError && !isYouTube)
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

              // 7. Platform Badge Overlay (Top Left)
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
                            platformIcon,
                            color: platformColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            platformLabel,
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

              // 8. Duration Badge (Bottom Right) — shown from API data immediately
              if (item.type == DownloadType.video && displayDuration.inSeconds > 0)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              _isInitialized
                                  ? '${_formatDuration(_currentPosition)} / ${_formatDuration(displayDuration)}'
                                  : _formatDuration(displayDuration),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 9. Seek progress bar (Bottom) — shown when video is playing
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
