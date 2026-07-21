enum ContentChannel { novel, shortDrama, video }

extension ContentChannelLabel on ContentChannel {
  String get label {
    switch (this) {
      case ContentChannel.novel:
        return '小说';
      case ContentChannel.shortDrama:
        return '短剧';
      case ContentChannel.video:
        return '影视';
    }
  }
}

class ContentItem {
  const ContentItem({
    required this.id,
    required this.channel,
    required this.title,
    required this.creator,
    required this.category,
    required this.summary,
    required this.coverAsset,
    required this.popularity,
    required this.progress,
    required this.episodeCount,
    this.sourceId = 'demo',
    this.sourceName = '演示数据',
    this.isLive = false,
    this.chapterUrls,
    this.localChapters,
  });

  final String id;
  final ContentChannel channel;
  final String title;
  final String creator;
  final String category;
  final String summary;
  final String coverAsset;
  final String popularity;
  final double progress;
  final int episodeCount;
  final String sourceId;
  final String sourceName;
  final bool isLive;
  final List<String>? chapterUrls;
  final List<Map<String, dynamic>>? localChapters;

  String get unitLabel => channel == ContentChannel.novel ? '章' : '集';

  ContentItem copyWith({double? progress}) => ContentItem(
    id: id,
    channel: channel,
    title: title,
    creator: creator,
    category: category,
    summary: summary,
    coverAsset: coverAsset,
    popularity: popularity,
    progress: progress ?? this.progress,
    episodeCount: episodeCount,
    sourceId: sourceId,
    sourceName: sourceName,
    isLive: isLive,
    chapterUrls: chapterUrls,
    localChapters: localChapters,
  );

  factory ContentItem.fromJson(Map<String, dynamic> json) => ContentItem(
    id: json['id'] as String,
    channel: ContentChannel.values.firstWhere(
      (value) => value.name == json['channel'],
      orElse: () => ContentChannel.novel,
    ),
    title: json['title'] as String? ?? '未命名内容',
    creator: json['creator'] as String? ?? '未知创作者',
    category: json['category'] as String? ?? '未分类',
    summary: json['summary'] as String? ?? '',
    coverAsset: json['cover'] as String? ?? '',
    popularity: json['popularity'] as String? ?? '',
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    episodeCount: json['unit_count'] as int? ?? 0,
    sourceId: json['source_id'] as String? ?? 'unknown',
    sourceName: json['source_name'] as String? ?? '未知来源',
    isLive: json['is_live'] as bool? ?? false,
    chapterUrls: (json['chapter_urls'] as List<dynamic>?)?.map((e) => e as String).toList(),
    localChapters: (json['chapters'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel': channel.name,
    'title': title,
    'creator': creator,
    'category': category,
    'summary': summary,
    'cover': coverAsset,
    'popularity': popularity,
    'progress': progress,
    'unit_count': episodeCount,
    'source_id': sourceId,
    'source_name': sourceName,
    'is_live': isLive,
    if (chapterUrls != null) 'chapter_urls': chapterUrls,
    if (localChapters != null) 'chapters': localChapters,
  };
}

class Chapter {
  const Chapter({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}
