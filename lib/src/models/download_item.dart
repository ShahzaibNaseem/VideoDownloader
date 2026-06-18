enum DownloadStatus {
  idle,
  fetching,
  downloading,
  completed,
  failed,
}

enum DownloadType {
  video,
  image,
  carousel,
}

enum MediaPlatform {
  tiktok,
  instagram,
  unknown,
}

class DownloadItem {
  final String id;
  final String url;
  final String title;
  final String thumbnailUrl;
  final double progress;
  final DownloadStatus status;
  final String fileSize;
  final String? filePath;
  final DownloadType type;
  final DateTime timestamp;

  // NEW real-API fields
  final String authorName;
  final MediaPlatform platform;

  /// Map of quality-label → CDN download URL
  /// e.g. { 'No Watermark': 'https://...', 'HD': 'https://...', 'Watermarked': 'https://...' }
  final Map<String, String> qualityOptions;

  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.progress,
    required this.status,
    required this.fileSize,
    this.filePath,
    required this.type,
    required this.timestamp,
    this.authorName = '',
    this.platform = MediaPlatform.unknown,
    this.qualityOptions = const {},
  });

  DownloadItem copyWith({
    String? id,
    String? url,
    String? title,
    String? thumbnailUrl,
    double? progress,
    DownloadStatus? status,
    String? fileSize,
    String? filePath,
    DownloadType? type,
    DateTime? timestamp,
    String? authorName,
    MediaPlatform? platform,
    Map<String, String>? qualityOptions,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      authorName: authorName ?? this.authorName,
      platform: platform ?? this.platform,
      qualityOptions: qualityOptions ?? this.qualityOptions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'progress': progress,
      'status': status.name,
      'fileSize': fileSize,
      'filePath': filePath,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'authorName': authorName,
      'platform': platform.name,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DownloadStatus.idle,
      ),
      fileSize: map['fileSize'] ?? '0 KB',
      filePath: map['filePath'],
      type: DownloadType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DownloadType.video,
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      authorName: map['authorName'] ?? '',
      platform: MediaPlatform.values.firstWhere(
        (e) => e.name == map['platform'],
        orElse: () => MediaPlatform.unknown,
      ),
    );
  }
}
