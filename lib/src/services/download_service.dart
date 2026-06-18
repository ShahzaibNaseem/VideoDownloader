import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart' hide Response;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_item.dart';

class DownloadService extends GetxService {
  late final Dio _dio;
  late final YoutubeExplode _yt;

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 10),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ));
    _yt = YoutubeExplode();
  }

  @override
  void onClose() {
    _yt.close();
    super.onClose();
  }

  // ─── URL Validation ─────────────────────────────────────────────────────────

  /// Detects which platform a URL belongs to.
  MediaPlatform detectPlatform(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('tiktok.com') || host.contains('vm.tiktok') || host.contains('vt.tiktok')) {
      return MediaPlatform.tiktok;
    }
    if (host.contains('instagram.com') || host.contains('instagr.am')) {
      return MediaPlatform.instagram;
    }
    if (host.contains('youtube.com') || host.contains('youtu.be') || host.contains('yt.be')) {
      return MediaPlatform.youtube;
    }
    return MediaPlatform.unknown;
  }

  /// Returns true if the URL is a supported TikTok, Instagram, or YouTube link.
  bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    return detectPlatform(url) != MediaPlatform.unknown;
  }

  // ─── Metadata Fetching ───────────────────────────────────────────────────────

  Future<DownloadItem> fetchMetadata(String url) async {
    final platform = detectPlatform(url);

    switch (platform) {
      case MediaPlatform.tiktok:
        return _fetchTikTokMetadata(url);
      case MediaPlatform.instagram:
        return _fetchInstagramMetadata(url);
      case MediaPlatform.youtube:
        return _fetchYouTubeMetadata(url);
      case MediaPlatform.unknown:
        throw Exception('Unsupported URL. Please enter a TikTok, Instagram, or YouTube link.');
    }
  }

  // ─── TikTok via TikWM ────────────────────────────────────────────────────────

  Future<DownloadItem> _fetchTikTokMetadata(String url) async {
    try {
      final response = await _dio.post(
        'https://www.tikwm.com/api/',
        data: 'url=${Uri.encodeComponent(url)}&hd=1',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final json = response.data as Map<String, dynamic>;

      if (json['code'] != 0) {
        throw Exception(json['msg'] ?? 'Failed to fetch TikTok video info. The video may be private or deleted.');
      }

      final data = json['data'] as Map<String, dynamic>;
      final author = data['author'] as Map<String, dynamic>? ?? {};

      final String title = (data['title'] as String? ?? '').isNotEmpty
          ? (data['title'] as String)
          : 'TikTok Video';
      final String thumbnail = data['cover'] as String? ?? data['origin_cover'] as String? ?? '';
      final String authorName = author['nickname'] as String? ?? author['unique_id'] as String? ?? '';

      // Duration from API
      final int durationSeconds = (data['duration'] as num?)?.toInt() ?? 0;

      // Collect quality options — prefer HD first, then no-watermark
      final Map<String, String> qualityOptions = {};
      final String? hdPlay = data['hdplay'] as String?;
      final String? noWatermark = data['play'] as String?;
      final String? wmPlay = data['wmplay'] as String?;

      // HD is highest quality — add first so it becomes default
      if (hdPlay != null && hdPlay.isNotEmpty) {
        qualityOptions['HD (No Watermark)'] = hdPlay;
      }
      if (noWatermark != null && noWatermark.isNotEmpty && noWatermark != hdPlay) {
        qualityOptions['No Watermark'] = noWatermark;
      }
      if (wmPlay != null && wmPlay.isNotEmpty) {
        qualityOptions['Watermarked'] = wmPlay;
      }

      // Estimate size (TikWM returns size in bytes under data['size'])
      final int? sizeBytes = data['size'] as int?;
      final String fileSize = sizeBytes != null
          ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
          : 'Unknown';

      return DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: title,
        thumbnailUrl: thumbnail,
        progress: 0.0,
        status: DownloadStatus.idle,
        fileSize: fileSize,
        type: DownloadType.video,
        timestamp: DateTime.now(),
        authorName: authorName,
        platform: MediaPlatform.tiktok,
        qualityOptions: qualityOptions,
        durationSeconds: durationSeconds,
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, 'TikTok'));
    }
  }

  // ─── Instagram — primary: SnapSave, fallback: SaveInsta ─────────────────────

  Future<DownloadItem> _fetchInstagramMetadata(String url) async {
    // Resolve share/redirect links first
    String targetUrl = _cleanInstagramUrl(url);
    if (url.contains('/share/') || url.contains('instagr.am')) {
      try {
        final r = await _dio.get(
          url,
          options: Options(
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        targetUrl = _cleanInstagramUrl(r.realUri.toString());
      } catch (_) {}
    }

    // Try primary backend first, then fall back
    try {
      return await _fetchInstagramViaSnapSave(targetUrl, url);
    } catch (e1) {
      try {
        return await _fetchInstagramViaSaveInsta(targetUrl, url);
      } catch (e2) {
        throw Exception('Could not fetch Instagram media. Please check the URL and try again.');
      }
    }
  }

  // ── Primary: SnapSave ──────────────────────────────────────────────────────

  Future<DownloadItem> _fetchInstagramViaSnapSave(String targetUrl, String originalUrl) async {
    // Step 1: fetch the SnapSave page to grab the CSRF token
    final pageResp = await _dio.get(
      'https://snapsave.app/',
      options: Options(
        headers: {
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    final pageHtml = pageResp.data.toString();

    // Extract _token (Laravel CSRF)
    final tokenMatch = RegExp(r'name="_token"\s+value="([^"]+)"').firstMatch(pageHtml);
    final token = tokenMatch?.group(1) ?? '';

    // Step 2: Submit the Instagram URL to SnapSave
    final resp = await _dio.post(
      'https://snapsave.app/action.php',
      data: 'url=${Uri.encodeComponent(targetUrl)}&lang=en&v=v2',
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Accept': '*/*',
          'Origin': 'https://snapsave.app',
          'Referer': 'https://snapsave.app/',
          if (token.isNotEmpty) 'X-CSRF-TOKEN': token,
        },
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // SnapSave returns JSON: {"status": "ok", "data": "<html>..."}
    final respData = resp.data;
    String htmlContent = '';
    if (respData is Map && respData['data'] != null) {
      htmlContent = respData['data'].toString();
    } else if (respData is String) {
      htmlContent = respData;
    }

    if (htmlContent.isEmpty) throw Exception('Empty response from SnapSave.');

    // Step 3: Parse download links from the returned HTML fragment
    return _parseSnapSaveHtml(htmlContent, originalUrl);
  }

  DownloadItem _parseSnapSaveHtml(String html, String originalUrl) {
    // SnapSave returns an HTML table with download rows.
    // Each row has: thumbnail, type label (Photo/Video), download link.
    final rows = <Map<String, dynamic>>[];

    // Extract all <tr> blocks
    final trRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    for (final tr in trRegex.allMatches(html)) {
      final trHtml = tr.group(1) ?? '';

      // Determine if this row is a video by looking for 'video' keyword or mp4
      final bool isVideo =
          trHtml.toLowerCase().contains('video') ||
          trHtml.toLowerCase().contains('.mp4') ||
          trHtml.toLowerCase().contains('mp4') ||
          trHtml.contains('icon-video');

      // Extract download href — prefer direct CDN links
      String? downloadUrl;
      final anchors = RegExp(r'href="(https?://[^"]+)"', caseSensitive: false)
          .allMatches(trHtml)
          .map((m) => m.group(1)!)
          .toList();

      // Prefer CDN video URL (cdninstagram, fbcdn, etc.)
      for (final href in anchors) {
        if (href.contains('cdninstagram') || href.contains('fbcdn') || href.contains('.mp4')) {
          downloadUrl = href;
          break;
        }
      }
      // Fall back to first link
      if (downloadUrl == null && anchors.isNotEmpty) {
        downloadUrl = anchors.first;
      }

      // Extract thumbnail from img src
      String? thumb;
      final imgMatch = RegExp(r'<img[^>]+src="([^"]+)"', caseSensitive: false).firstMatch(trHtml);
      if (imgMatch != null) thumb = imgMatch.group(1);

      if (downloadUrl != null && downloadUrl.startsWith('http')) {
        rows.add({'url': downloadUrl, 'isVideo': isVideo, 'thumbnail': thumb});
      }
    }

    // If no rows found via <tr>, try flat <a> link extraction (some response formats)
    if (rows.isEmpty) {
      final allLinks = RegExp(r'href="(https?://[^"]+)"', caseSensitive: false)
          .allMatches(html)
          .map((m) => m.group(1)!)
          .where((u) => u.contains('cdninstagram') || u.contains('fbcdn') || u.contains('snapsave'))
          .toList();

      for (final link in allLinks) {
        rows.add({
          'url': link,
          'isVideo': link.contains('.mp4') || link.contains('video'),
          'thumbnail': null,
        });
      }
    }

    if (rows.isEmpty) throw Exception('No media found in SnapSave response.');

    // Separate videos from images; prefer video rows
    final videoRows = rows.where((r) => r['isVideo'] == true).toList();
    final imageRows = rows.where((r) => r['isVideo'] != true).toList();

    final bool isCarousel = rows.length > 1 && imageRows.length > 1;
    final bool hasVideo = videoRows.isNotEmpty;

    String thumbnail = '';
    for (final r in rows) {
      if (r['thumbnail'] != null) { thumbnail = r['thumbnail'] as String; break; }
    }

    final Map<String, String> qualityOptions = {};
    if (isCarousel) {
      // Carousel: each item is separate
      for (int i = 0; i < rows.length; i++) {
        qualityOptions['Item ${i + 1}'] = rows[i]['url'] as String;
      }
    } else if (hasVideo) {
      // Video reel — may have multiple quality variants
      for (int i = 0; i < videoRows.length; i++) {
        final label = videoRows.length == 1 ? 'Download' : 'Quality ${i + 1}';
        qualityOptions[label] = videoRows[i]['url'] as String;
      }
    } else {
      qualityOptions['Download'] = rows.first['url'] as String;
    }

    final DownloadType dtype = isCarousel
        ? DownloadType.carousel
        : (hasVideo ? DownloadType.video : DownloadType.image);

    return DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: originalUrl,
      title: isCarousel
          ? 'Instagram Carousel (${rows.length} items)'
          : (hasVideo ? 'Instagram Reel' : 'Instagram Photo'),
      thumbnailUrl: thumbnail,
      progress: 0.0,
      status: DownloadStatus.idle,
      fileSize: 'Checking...',
      type: dtype,
      timestamp: DateTime.now(),
      authorName: '',
      platform: MediaPlatform.instagram,
      qualityOptions: qualityOptions,
      durationSeconds: 0,
    );
  }

  // ── Fallback: SaveInsta ────────────────────────────────────────────────────

  Future<DownloadItem> _fetchInstagramViaSaveInsta(String targetUrl, String originalUrl) async {
    // Step 1: Fetch highlights HTML from saveinsta.to to get tokens
    final response1 = await _dio.get(
      'https://saveinsta.to/en/highlights',
      options: Options(
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': 'https://www.google.com/',
        },
      ),
    );

    final html = response1.data.toString();
    final scriptRegExp = RegExp(
        r'<script[^>]*>var\s+k_url_search="[^"]+"(.*?)<\/script>',
        dotAll: true);
    final match = scriptRegExp.firstMatch(html);
    if (match == null) throw Exception('SaveInsta: JS block not found.');

    final scriptBlock = match.group(1) ?? '';
    String? extractJsVar(String name, String source) {
      final m = RegExp('$name\\s*=\\s*"([^"]+)"').firstMatch(source);
      return m?.group(1);
    }
    final kExp = extractJsVar('k_exp', scriptBlock);
    final kToken = extractJsVar('k_token', scriptBlock);
    if (kExp == null || kToken == null) throw Exception('SaveInsta: security keys not found.');

    await Future.delayed(const Duration(milliseconds: 1200));

    final response2 = await _dio.post(
      'https://saveinsta.to/api/userverify',
      data: {'url': targetUrl},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Accept': '*/*',
          'Origin': 'https://saveinsta.to',
          'Referer': 'https://saveinsta.to/en/video',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );
    final cftoken = response2.data?['token'];
    if (cftoken == null) throw Exception('SaveInsta: verification token missing.');

    await Future.delayed(const Duration(milliseconds: 1200));

    final response3 = await _dio.post(
      'https://saveinsta.to/api/ajaxSearch',
      data: {
        'k_exp': kExp, 'k_token': kToken, 'q': targetUrl,
        't': 'media', 'lang': 'en', 'v': 'v2', 'cftoken': cftoken,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Accept': '*/*',
          'Origin': 'https://saveinsta.to',
          'Referer': 'https://saveinsta.to/en/highlights',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    final finalData = response3.data;
    if (finalData == null || finalData['status'] != 'ok') {
      final msg = finalData?['mess'] ?? 'Unknown error.';
      throw Exception(msg.toString().replaceAll(RegExp(r'<[^>]*>'), ''));
    }

    final String finalHtml = finalData['data'] ?? '';
    if (finalHtml.isEmpty) throw Exception('SaveInsta: no media links returned.');

    // Parse HTML — look for any video or image download links
    final liRegex = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true);
    final extracted = <Map<String, dynamic>>[];

    for (final liMatch in liRegex.allMatches(finalHtml)) {
      final liHtml = liMatch.group(1) ?? '';

      // Video detection — check multiple indicators
      final bool isVideo =
          liHtml.contains('icon-dlvideo') ||
          liHtml.contains('video=') ||
          liHtml.contains('Download Video') ||
          liHtml.toLowerCase().contains('.mp4') ||
          liHtml.toLowerCase().contains('mp4') ||
          liHtml.toLowerCase().contains('video');

      String? downloadUrl;
      final aRegex = RegExp(r'<a[^>]+href="([^"]+)"', caseSensitive: false);
      for (final aMatch in aRegex.allMatches(liHtml)) {
        final href = aMatch.group(1);
        if (href != null && href.startsWith('http')) {
          if (href.contains('token=') || href.contains('download') ||
              href.contains('cdninstagram') || href.contains('fbcdn')) {
            downloadUrl = href;
            break;
          }
        }
      }
      downloadUrl ??= aRegex.allMatches(liHtml)
          .map((m) => m.group(1))
          .firstWhere((h) => h != null && h.startsWith('http'), orElse: () => null);

      String? thumbUrl;
      final imgMatch = RegExp(r'<img[^>]+(?:src|data-src)="([^"]+)"', caseSensitive: false)
          .firstMatch(liHtml);
      if (imgMatch != null) thumbUrl = imgMatch.group(1);

      if (downloadUrl != null) {
        extracted.add({'url': downloadUrl, 'thumbnail': thumbUrl, 'isVideo': isVideo});
      }
    }

    if (extracted.isEmpty) throw Exception('SaveInsta: no downloadable media found.');

    final bool isCarousel = extracted.length > 1;
    final videoRows = extracted.where((e) => e['isVideo'] == true).toList();
    final bool hasVideo = videoRows.isNotEmpty;

    final String thumbnail = extracted.first['thumbnail'] as String? ?? '';
    final Map<String, String> qualityOptions = {};

    if (isCarousel) {
      for (int i = 0; i < extracted.length; i++) {
        qualityOptions['Item ${i + 1}'] = extracted[i]['url'] as String;
      }
    } else if (hasVideo) {
      qualityOptions['Download'] = videoRows.first['url'] as String;
    } else {
      qualityOptions['Download'] = extracted.first['url'] as String;
    }

    final DownloadType dtype = isCarousel
        ? DownloadType.carousel
        : (hasVideo ? DownloadType.video : DownloadType.image);

    return DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: originalUrl,
      title: isCarousel
          ? 'Instagram Carousel (${extracted.length} items)'
          : (hasVideo ? 'Instagram Reel' : 'Instagram Photo'),
      thumbnailUrl: thumbnail,
      progress: 0.0,
      status: DownloadStatus.idle,
      fileSize: 'Checking...',
      type: dtype,
      timestamp: DateTime.now(),
      authorName: '',
      platform: MediaPlatform.instagram,
      qualityOptions: qualityOptions,
      durationSeconds: 0,
    );
  }

  // ─── YouTube via youtube_explode_dart ────────────────────────────────────────


  Future<DownloadItem> _fetchYouTubeMetadata(String url) async {
    try {
      // Pre-process the URL to extract a clean video ID — handles Shorts, youtu.be,
      // regular watch URLs, and strips tracking params like ?si= that confuse the library.
      final String rawId = _extractYouTubeVideoId(url);
      if (rawId.isEmpty) {
        throw Exception('Could not extract a YouTube video ID from this URL. Please copy the URL directly from YouTube.');
      }

      final videoId = VideoId(rawId);
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Build quality options from muxed streams (video+audio combined)
      // For best quality: use muxed streams up to 1080p, prefer highest available
      final Map<String, String> qualityOptions = {};

      // Sort muxed streams by bitrate descending (higher = better quality)
      final muxedStreams = manifest.muxed.toList()
        ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

      // Label priority mapping
      final Map<String, String> addedResolutions = {};
      for (final stream in muxedStreams) {
        final label = _ytQualityLabel(stream.videoQuality);
        if (!addedResolutions.containsKey(label)) {
          // Store as URL directly
          qualityOptions[label] = stream.url.toString();
          addedResolutions[label] = stream.url.toString();
        }
      }

      // If no muxed streams, fall back to highest-quality video-only + best audio
      // (We still offer a combined download path)
      if (qualityOptions.isEmpty) {
        final videoStreams = manifest.videoOnly.toList()
          ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        for (final stream in videoStreams.take(3)) {
          final label = _ytQualityLabel(stream.videoQuality);
          if (!qualityOptions.containsKey(label)) {
            qualityOptions[label] = stream.url.toString();
          }
        }
      }

      if (qualityOptions.isEmpty) {
        throw Exception('No downloadable streams found for this YouTube video.');
      }

      // Duration
      final int durationSec = video.duration?.inSeconds ?? 0;

      // File size estimate from highest quality stream
      final String fileSize = muxedStreams.isNotEmpty
          ? '${(muxedStreams.first.size.totalMegaBytes).toStringAsFixed(1)} MB'
          : 'Unknown';

      // Thumbnail: use maxres thumbnail
      final String thumbnail = 'https://img.youtube.com/vi/${video.id.value}/maxresdefault.jpg';

      return DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: video.title,
        thumbnailUrl: thumbnail,
        progress: 0.0,
        status: DownloadStatus.idle,
        fileSize: fileSize,
        type: DownloadType.video,
        timestamp: DateTime.now(),
        authorName: video.author,
        platform: MediaPlatform.youtube,
        qualityOptions: qualityOptions,
        durationSeconds: durationSec,
      );
    } on VideoUnavailableException catch (_) {
      throw Exception('This YouTube video is unavailable or private.');
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      throw Exception('YouTube: $msg');
    }
  }

  /// Maps VideoQuality to a human-readable label
  String _ytQualityLabel(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.high2160:
        return '4K (2160p)';
      case VideoQuality.high1440:
        return 'QHD (1440p)';
      case VideoQuality.high1080:
        return 'Full HD (1080p)';
      case VideoQuality.high720:
        return 'HD (720p)';
      case VideoQuality.medium480:
        return 'SD (480p)';
      case VideoQuality.medium360:
        return 'Low (360p)';
      case VideoQuality.low240:
        return 'Lowest (240p)';
      default:
        return quality.name;
    }
  }

  // ─── File Download ────────────────────────────────────────────────────────

  /// Downloads the file at [downloadUrl] with real-time progress, saves to gallery.
  /// Yields values from 0.0 to 1.0. Throws on error.
  Stream<double> downloadFile(DownloadItem item, String quality) async* {
    final String? downloadUrl = item.qualityOptions[quality];
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw Exception('No download URL available for quality: $quality');
    }

    // 1. Proactively check and request gallery write access
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw Exception('Gallery write permission denied. Please allow access in settings to download.');
      }
    }

    // Route to platform-specific downloader
    if (item.platform == MediaPlatform.youtube) {
      yield* _downloadYouTubeFile(item, downloadUrl);
    } else {
      yield* _downloadDirectFile(item, quality, downloadUrl);
    }
  }

  // ─── Direct HTTP Download (TikTok / Instagram) ───────────────────────────

  Stream<double> _downloadDirectFile(
    DownloadItem item,
    String quality,
    String downloadUrl,
  ) async* {
    // Detect file type — first check URL extension, then content-type via HEAD
    final String urlLower = downloadUrl.toLowerCase();
    bool reallyIsVideo = item.type == DownloadType.video || item.type == DownloadType.carousel;

    if (urlLower.contains('.mp4') || urlLower.contains('.m4v') || urlLower.contains('.mov')) {
      reallyIsVideo = true;
    } else if (urlLower.contains('.jpg') || urlLower.contains('.jpeg') ||
        urlLower.contains('.png') || urlLower.contains('.webp')) {
      reallyIsVideo = false;
    } else {
      // No extension in URL — do a lightweight HEAD request to check Content-Type.
      // This is the safeguard that prevents saving images as .mp4 (0-second videos).
      try {
        final headResp = await _dio.head(
          downloadUrl,
          options: Options(
            followRedirects: true,
            maxRedirects: 5,
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
        final ct = headResp.headers.value('content-type') ?? '';
        if (ct.contains('video')) {
          reallyIsVideo = true;
        } else if (ct.contains('image')) {
          reallyIsVideo = false;
        }
        // If content-type is empty or ambiguous, keep the type from DownloadItem
      } catch (_) {
        // HEAD failed — trust the DownloadItem type
      }
    }

    final String ext = reallyIsVideo ? 'mp4' : 'jpg';
    final String fileName = 'glowload_${item.id}_${quality.replaceAll(' ', '_')}.$ext';

    // Use documents directory (stable, unfragmented) for staging
    final Directory stageDir = await _getStagingDirectory();
    final String tempPath = '${stageDir.path}/$fileName';

    final StreamController<double> progressController = StreamController<double>();

    // Run download asynchronously and feed progress into the stream
    _dio.download(
      downloadUrl,
      tempPath,
      deleteOnError: true,
      options: Options(
        receiveTimeout: const Duration(minutes: 15),
        followRedirects: true,
        maxRedirects: 5,
      ),
      onReceiveProgress: (received, total) {
        if (total > 0 && !progressController.isClosed) {
          progressController.add(received / total);
        } else if (!progressController.isClosed) {
          // Indeterminate — pulse at 0.5 so UI knows it's working
          progressController.add(0.5);
        }
      },
    ).then((_) async {
      // Save to gallery
      if (reallyIsVideo) {
        await Gal.putVideo(tempPath, album: 'GlowLoad');
      } else {
        await Gal.putImage(tempPath, album: 'GlowLoad');
      }

      // Clean up staging file
      try {
        final f = File(tempPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}

      if (!progressController.isClosed) {
        progressController.add(1.0);
        await progressController.close();
      }
    }).catchError((Object err) {
      if (!progressController.isClosed) {
        progressController.addError(
          Exception('Download failed: ${err.toString().replaceAll('Exception:', '').trim()}'),
        );
        progressController.close();
      }
    });

    yield* progressController.stream;
  }

  // ─── YouTube Stream Download ─────────────────────────────────────────────

  Stream<double> _downloadYouTubeFile(
    DownloadItem item,
    String streamUrl,
  ) async* {
    final StreamController<double> progressController = StreamController<double>();

    _downloadYouTubeAsync(item, streamUrl, progressController);

    yield* progressController.stream;
  }

  Future<void> _downloadYouTubeAsync(
    DownloadItem item,
    String streamUrl,
    StreamController<double> progressController,
  ) async {
    try {
      final String fileName = 'glowload_yt_${item.id}.mp4';
      final Directory stageDir = await _getStagingDirectory();
      final String stagePath = '${stageDir.path}/$fileName';
      final File stageFile = File(stagePath);

      // Download using Dio with progress
      await _dio.download(
        streamUrl,
        stagePath,
        deleteOnError: true,
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          followRedirects: true,
          maxRedirects: 5,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && !progressController.isClosed) {
            progressController.add(received / total);
          } else if (!progressController.isClosed) {
            progressController.add(0.5);
          }
        },
      );

      // Save to gallery
      await Gal.putVideo(stagePath, album: 'GlowLoad');

      // Clean up
      try {
        if (await stageFile.exists()) await stageFile.delete();
      } catch (_) {}

      if (!progressController.isClosed) {
        progressController.add(1.0);
        await progressController.close();
      }
    } catch (e) {
      if (!progressController.isClosed) {
        progressController.addError(
          Exception('YouTube download failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
        );
        progressController.close();
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Returns a stable staging directory (not the fragmented temp cache).
  Future<Directory> _getStagingDirectory() async {
    Directory base;
    if (Platform.isAndroid) {
      base = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final stagingDir = Directory('${base.path}/glowload_staging');
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }
    return stagingDir;
  }

  String _cleanInstagramUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Keep only the path — strip query params and fragments that confuse scrapers
      return '${uri.scheme}://${uri.host}${uri.path}';
    } catch (_) {
      return url;
    }
  }

  /// Extracts a bare YouTube video ID from any supported YouTube URL format:
  ///   • https://www.youtube.com/watch?v=VIDEO_ID
  ///   • https://youtu.be/VIDEO_ID
  ///   • https://youtube.com/shorts/VIDEO_ID          ← Shorts
  ///   • https://youtube.com/shorts/VIDEO_ID?si=...   ← Shorts with tracking
  ///   • https://www.youtube.com/embed/VIDEO_ID
  ///   • https://www.youtube.com/live/VIDEO_ID
  ///
  /// Returns an empty string if no valid ID could be found.
  String _extractYouTubeVideoId(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final host = uri.host.toLowerCase();
      final path = uri.path;

      // ── youtu.be/VIDEO_ID ────────────────────────────────────────────────────
      if (host == 'youtu.be' || host == 'www.youtu.be') {
        final id = path.split('/').where((s) => s.isNotEmpty).firstOrNull ?? '';
        return _sanitizeYtId(id);
      }

      // ── youtube.com paths ────────────────────────────────────────────────────
      if (host.contains('youtube.com') || host.contains('yt.be')) {
        // /shorts/VIDEO_ID
        final shortsMatch = RegExp(r'/shorts/([A-Za-z0-9_-]+)').firstMatch(path);
        if (shortsMatch != null) return _sanitizeYtId(shortsMatch.group(1) ?? '');

        // /embed/VIDEO_ID
        final embedMatch = RegExp(r'/embed/([A-Za-z0-9_-]+)').firstMatch(path);
        if (embedMatch != null) return _sanitizeYtId(embedMatch.group(1) ?? '');

        // /live/VIDEO_ID
        final liveMatch = RegExp(r'/live/([A-Za-z0-9_-]+)').firstMatch(path);
        if (liveMatch != null) return _sanitizeYtId(liveMatch.group(1) ?? '');

        // ?v=VIDEO_ID  (regular watch URL)
        final v = uri.queryParameters['v'] ?? '';
        if (v.isNotEmpty) return _sanitizeYtId(v);

        // /v/VIDEO_ID  (legacy)
        final vPathMatch = RegExp(r'/v/([A-Za-z0-9_-]+)').firstMatch(path);
        if (vPathMatch != null) return _sanitizeYtId(vPathMatch.group(1) ?? '');
      }

      // ── Bare 11-character ID passed directly ─────────────────────────────────
      final bareId = RegExp(r'^[A-Za-z0-9_-]{11}$').firstMatch(url.trim());
      if (bareId != null) return url.trim();

    } catch (_) {}

    return '';
  }

  /// Strips any extra characters (query params, fragments) that may have
  /// been accidentally included in the extracted segment, and validates length.
  String _sanitizeYtId(String raw) {
    // Remove anything after ? or # or &
    final clean = raw.split(RegExp(r'[?&#]')).first.trim();
    // YouTube IDs are always 11 characters of [A-Za-z0-9_-]
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(clean)) return clean;
    return '';
  }

  String _mapDioError(DioException e, String platform) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network settings.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 429) return 'Too many requests. Please wait a moment and try again.';
        if (status == 404) return '$platform post not found. The content may have been deleted.';
        if (status != null && status >= 500) return '$platform server error. Please try again later.';
        return 'Server returned an unexpected error (code $status).';
      default:
        return 'Failed to connect to the $platform download service. Please try again.';
    }
  }
}
