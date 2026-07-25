import '../domain/content.dart';

enum OfflineDownloadState { partial, completed, failed }

class OfflineBookRecord {
  const OfflineBookRecord({
    required this.item,
    required this.sourceId,
    required this.chapterIndexes,
    required this.updatedAt,
    required this.bytes,
    this.failedChapterIndexes = const {},
  });

  final ContentItem item;
  final String sourceId;
  final Set<int> chapterIndexes;
  final Set<int> failedChapterIndexes;
  final DateTime updatedAt;
  final int bytes;

  int get downloadedCount => chapterIndexes.length;
  double get progress => item.episodeCount <= 0
      ? 0
      : (downloadedCount / item.episodeCount).clamp(0, 1);
  OfflineDownloadState get state {
    if (failedChapterIndexes.isNotEmpty) return OfflineDownloadState.failed;
    return downloadedCount >= item.episodeCount
        ? OfflineDownloadState.completed
        : OfflineDownloadState.partial;
  }

  OfflineBookRecord copyWith({
    ContentItem? item,
    String? sourceId,
    Set<int>? chapterIndexes,
    Set<int>? failedChapterIndexes,
    DateTime? updatedAt,
    int? bytes,
  }) => OfflineBookRecord(
    item: item ?? this.item,
    sourceId: sourceId ?? this.sourceId,
    chapterIndexes: chapterIndexes ?? this.chapterIndexes,
    failedChapterIndexes: failedChapterIndexes ?? this.failedChapterIndexes,
    updatedAt: updatedAt ?? this.updatedAt,
    bytes: bytes ?? this.bytes,
  );

  factory OfflineBookRecord.fromJson(Map<String, dynamic> json) =>
      OfflineBookRecord(
        item: ContentItem.fromJson(
          Map<String, dynamic>.from(json['item'] as Map),
        ),
        sourceId: json['source_id'] as String? ?? 'unknown',
        chapterIndexes: (json['chapters'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toSet(),
        failedChapterIndexes:
            (json['failed_chapters'] as List<dynamic>? ?? const [])
                .map((value) => (value as num).toInt())
                .toSet(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'source_id': sourceId,
    'chapters': chapterIndexes.toList()..sort(),
    'failed_chapters': failedChapterIndexes.toList()..sort(),
    'updated_at': updatedAt.toIso8601String(),
    'bytes': bytes,
  };
}

class OfflineBookStatus {
  const OfflineBookStatus({
    required this.downloadedCount,
    required this.totalCount,
    required this.failedCount,
  });

  static const empty = OfflineBookStatus(
    downloadedCount: 0,
    totalCount: 0,
    failedCount: 0,
  );

  final int downloadedCount;
  final int totalCount;
  final int failedCount;

  bool get hasDownload => downloadedCount > 0;
  bool get isComplete => totalCount > 0 && downloadedCount >= totalCount;
}
