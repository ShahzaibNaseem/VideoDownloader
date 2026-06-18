import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart' hide Response;
import 'package:path_provider/path_provider.dart';
import '../models/download_item.dart';

class DownloadService extends GetxService {
  late final Dio _dio;

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ));
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
    return MediaPlatform.unknown;
  }

  /// Returns true if the URL is a supported TikTok or Instagram link.
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
      case MediaPlatform.unknown:
        throw Exception('Unsupported URL. Please enter a TikTok or Instagram link.');
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

      // Collect quality options — only include keys that have valid URLs
      final Map<String, String> qualityOptions = {};
      final String? noWatermark = data['play'] as String?;
      final String? hdPlay = data['hdplay'] as String?;
      final String? wmPlay = data['wmplay'] as String?;

      if (noWatermark != null && noWatermark.isNotEmpty) {
        qualityOptions['No Watermark'] = noWatermark;
      }
      if (hdPlay != null && hdPlay.isNotEmpty && hdPlay != noWatermark) {
        qualityOptions['HD'] = hdPlay;
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
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, 'TikTok'));
    }
  }

  // ─── Instagram via SaveInsta Scraper ───────────────────────────────────────

  Future<DownloadItem> _fetchInstagramMetadata(String url) async {
    try {
      var targetUrl = _cleanInstagramUrl(url);
      if (url.contains('/share/') || url.contains('instagr.am')) {
        final redirectResponse = await _dio.get(
          url,
          options: Options(
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        targetUrl = _cleanInstagramUrl(redirectResponse.realUri.toString());
      }

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
      if (match == null) {
        throw Exception('Failed to initialize download tokens (JS block not found).');
      }

      final scriptBlock = match.group(1) ?? '';
      
      String? extractJsVar(String name, String source) {
        final regExp = RegExp('$name\\s*=\\s*"([^"]+)"');
        final m = regExp.firstMatch(source);
        return m?.group(1);
      }

      final kExp = extractJsVar('k_exp', scriptBlock);
      final kToken = extractJsVar('k_token', scriptBlock);

      if (kExp == null || kToken == null) {
        throw Exception('Failed to parse download security keys.');
      }

      // Step 2: Delay
      await Future.delayed(const Duration(milliseconds: 1200));

      // Step 3: Get CF token via userverify
      final response2 = await _dio.post(
        'https://saveinsta.to/api/userverify',
        data: {
          'url': targetUrl,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Origin': 'https://saveinsta.to',
            'Referer': 'https://saveinsta.to/en/video',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      final cftokenData = response2.data;
      if (cftokenData == null || cftokenData['token'] == null) {
        throw Exception('Failed to obtain verification token from server.');
      }

      final cftoken = cftokenData['token'];

      // Step 4: Delay
      await Future.delayed(const Duration(milliseconds: 1200));

      // Step 5: Request final content from ajaxSearch
      final response3 = await _dio.post(
        'https://saveinsta.to/api/ajaxSearch',
        data: {
          'k_exp': kExp,
          'k_token': kToken,
          'q': targetUrl,
          't': 'media',
          'lang': 'en',
          'v': 'v2',
          'cftoken': cftoken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Origin': 'https://saveinsta.to',
            'Referer': 'https://saveinsta.to/en/highlights',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      final finalData = response3.data;
      if (finalData == null || finalData['status'] != 'ok') {
        final message = finalData?['mess'] ?? 'Unknown download error.';
        throw Exception(message.toString().replaceAll(RegExp(r'<[^>]*>'), ''));
      }

      final String finalHtml = finalData['data'] ?? '';
      if (finalHtml.isEmpty) {
        throw Exception('No media links returned by downloader backend.');
      }

      // Step 6: Parse final HTML
      final liRegex = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true);
      final liMatches = liRegex.allMatches(finalHtml);
      final extracted = <Map<String, dynamic>>[];

      for (final liMatch in liMatches) {
        final liHtml = liMatch.group(1) ?? '';
        
        // 1. Determine type (image or video)
        bool isVideo = false;
        if (liHtml.contains('icon-dlvideo') || liHtml.contains('video="') || liHtml.contains('Download Video')) {
          isVideo = true;
        }
        
        // 2. Extract download URL
        String? downloadUrl;
        final aRegex = RegExp(r'<a[^>]+href="([^"]+)"', caseSensitive: false);
        final aMatches = aRegex.allMatches(liHtml);
        for (final aMatch in aMatches) {
          final href = aMatch.group(1);
          if (href != null && href.startsWith('http')) {
            if (href.contains('token=') || href.contains('download')) {
              downloadUrl = href;
              break;
            }
          }
        }
        
        if (downloadUrl == null) {
          for (final aMatch in aMatches) {
            final href = aMatch.group(1);
            if (href != null && href.startsWith('http')) {
              downloadUrl = href;
              break;
            }
          }
        }
        
        // 3. Extract thumbnail
        String? thumbUrl;
        final imgRegex = RegExp(r'<img[^>]+(?:src|data-src)="([^"]+)"', caseSensitive: false);
        final imgMatch = imgRegex.firstMatch(liHtml);
        if (imgMatch != null) {
          thumbUrl = imgMatch.group(1);
          if (thumbUrl != null && (thumbUrl.contains('loader.gif') || thumbUrl.contains('placeholder'))) {
            final dataSrcRegex = RegExp(r'data-src="([^"]+)"', caseSensitive: false);
            final dataSrcMatch = dataSrcRegex.firstMatch(liHtml);
            if (dataSrcMatch != null) {
              thumbUrl = dataSrcMatch.group(1);
            }
          }
        }
        
        if (downloadUrl != null) {
          extracted.add({
            'url': downloadUrl,
            'thumbnail': thumbUrl,
            'isVideo': isVideo,
          });
        }
      }

      if (extracted.isEmpty) {
        throw Exception('No downloadable media found at this Instagram URL.');
      }

      final bool isCarousel = extracted.length > 1;
      final bool firstIsVideo = extracted.first['isVideo'] == true;
      final DownloadType downloadType = isCarousel
          ? DownloadType.carousel
          : (firstIsVideo ? DownloadType.video : DownloadType.image);

      final String thumbnail = extracted.first['thumbnail'] as String? ?? '';

      final Map<String, String> qualityOptions = {};
      for (int i = 0; i < extracted.length; i++) {
        final item = extracted[i];
        final String itemUrl = item['url'] as String;
        if (isCarousel) {
          qualityOptions['Item ${i + 1}'] = itemUrl;
        } else {
          qualityOptions['Download'] = itemUrl;
        }
      }

      return DownloadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: isCarousel
            ? 'Instagram Carousel (${extracted.length} items)'
            : (firstIsVideo ? 'Instagram Reel' : 'Instagram Photo'),
        thumbnailUrl: thumbnail,
        progress: 0.0,
        status: DownloadStatus.idle,
        fileSize: 'Checking...',
        type: downloadType,
        timestamp: DateTime.now(),
        authorName: '',
        platform: MediaPlatform.instagram,
        qualityOptions: qualityOptions,
      );
    } on DioException catch (e) {
      throw Exception(_mapDioError(e, 'Instagram'));
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
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

    // 2. Detect file type from the CDN URL
    final String urlLower = downloadUrl.toLowerCase();
    bool reallyIsVideo = item.type == DownloadType.video || item.type == DownloadType.carousel;
    if (urlLower.contains('.mp4') || urlLower.contains('.m4v') || urlLower.contains('.mov')) {
      reallyIsVideo = true;
    } else if (urlLower.contains('.jpg') || urlLower.contains('.jpeg') || urlLower.contains('.png') || urlLower.contains('.webp')) {
      reallyIsVideo = false;
    }

    final String ext = reallyIsVideo ? 'mp4' : 'jpg';
    final String fileName = 'glowload_${item.id}_${quality.replaceAll(' ', '_')}.$ext';

    // Stage file in app temp directory
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = '${tempDir.path}/$fileName';

    final StreamController<double> progressController = StreamController<double>();

    // Run download asynchronously and feed progress into the stream
    _dio.download(
      downloadUrl,
      tempPath,
      deleteOnError: true,
      options: Options(
        receiveTimeout: const Duration(minutes: 10),
        followRedirects: true,
        maxRedirects: 5,
      ),
      onReceiveProgress: (received, total) {
        if (total > 0 && !progressController.isClosed) {
          progressController.add(received / total);
        }
      },
    ).then((_) async {
      // Save to gallery
      if (reallyIsVideo) {
        await Gal.putVideo(tempPath, album: 'GlowLoad');
      } else {
        await Gal.putImage(tempPath, album: 'GlowLoad');
      }

      // Clean up temp file
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _cleanInstagramUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Keep only the path — strip query params and fragments that confuse scrapers
      return '${uri.scheme}://${uri.host}${uri.path}';
    } catch (_) {
      return url;
    }
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
